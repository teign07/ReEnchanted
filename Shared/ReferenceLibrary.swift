import Foundation


struct ReferenceSnippet: Codable, Identifiable, Equatable {
    var id: String
    var sourceID: String
    var title: String
    var prompt: String
    var body: String
    var tags: [String]
    /// An invitation the Book hands the reader: a small thing to try, notice,
    /// or answer in the real world. Optional so older bundles still decode.
    var practice: String? = nil
    var url: String? = nil
    var publishedAt: String? = nil
    var preview: String? = nil

    /// The living Book offers a small piece first. The complete source page is
    /// still present in `body`, but it belongs behind a deliberate reading
    /// door; pouring a whole chapter into Pages Rising can turn one reference
    /// into hundreds of transient leaves.
    var leafExcerpt: String {
        let source = preview?.nonEmpty ?? body.nonEmpty ?? prompt
        return source.bookPreviewSentenceLimit(2)
    }
}

struct LabyrinthIllustrationPlate: Identifiable, Equatable {
    var id: String
    var assetName: String
    var title: String
    var caption: String
    var note: String
    var tags: [String]
    var characterID: String? = nil
}

/// A pack opts art into this encounter explicitly; print plates are not
/// silently borrowed before their authored story beat.
struct InterleafIllustration: Codable, Identifiable, Equatable {
    var id: String
    var assetName: String
    var title: String
    var tags: [String]
    var placementTrigger: IlluminationPlacementTrigger? = nil

    var resolvedAssetName: String { MonthlyIssueMediaPath.resolving(assetName) }

    func isEligible(in context: IlluminationPlacementContext) -> Bool {
        if let year = placementTrigger?.issueYear, context.year != year { return false }
        return placementTrigger?.allows(context) ?? true
    }
}

enum InterleafIllustrationLibrary {
    /// Permanent illustrated field leaves. They share the cast plates'
    /// subject matching and recent-image exclusion, without a monthly gate.
    static let permanentScenes: [InterleafIllustration] = [
        InterleafIllustration(
            id: "evergreen::shelf-that-kept-growing",
            assetName: "InterleafShelfThatKeptGrowing",
            title: "The shelf that kept growing",
            tags: ["library", "books", "growth", "tree", "stacks", "nature", "wonder", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::under-the-kitchen-table",
            assetName: "InterleafUnderTheKitchenTable",
            title: "Under the Kitchen table",
            tags: ["kitchen", "food", "goblin", "repair", "care", "craft", "home", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::the-books-sleeping-place",
            assetName: "InterleafBooksSleepingPlace",
            title: "The Book’s sleeping place",
            tags: ["rest", "sleep", "roots", "burrow", "shelter", "home", "quiet", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::the-window-after-everyone-leaves",
            assetName: "InterleafWindowAfterEveryoneLeaves",
            title: "The window after everyone leaves",
            tags: ["window", "evening", "quiet", "tea", "paper", "bird", "rest", "observation", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::a-way-into-the-story",
            assetName: "InterleafWayIntoTheStory",
            title: "A way into the story",
            tags: ["book-jump", "professor-permancer", "story", "door", "threshold", "adventure", "wonder", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::the-word-duel",
            assetName: "InterleafWordDuel",
            title: "The word duel",
            tags: ["word", "duel", "writing", "ink", "quill", "punctuation", "play", "penny-blackletter", "professor-permancer", "labyrinth"]
        ),
        InterleafIllustration(
            id: "evergreen::the-forgotten-stacks",
            assetName: "InterleafForgottenStacks",
            title: "The forgotten stacks",
            tags: ["library", "stacks", "shadow", "grey", "curse", "nothing", "night", "secret", "mystery", "labyrinth"]
        )
    ]

    /// Pure selection is also used by proof fixtures. Recent plates are
    /// excluded when there is another eligible choice, never by random retry.
    static func select(from plates: [InterleafIllustration], context: IlluminationPlacementContext, seed: Int, excluding: Set<String> = []) -> InterleafIllustration? {
        let eligible = plates.filter { $0.isEligible(in: context) }
        let fresh = eligible.filter { !excluding.contains($0.resolvedAssetName) }
        let candidates = fresh.isEmpty ? eligible : fresh
        guard !candidates.isEmpty else { return nil }
        let subjects = Set(context.semanticTags.map { $0.lowercased() })
        func score(_ plate: InterleafIllustration) -> Int {
            Set(plate.tags.map { $0.lowercased() }).intersection(subjects).count
        }
        let best = candidates.map(score).max() ?? 0
        let related = candidates.filter { score($0) == best }.sorted {
            if $0.id != $1.id { return $0.id < $1.id }
            return $0.assetName < $1.assetName
        }
        let index = Int(UInt(bitPattern: seed.stableScramble) % UInt(related.count))
        return related[index]
    }

    static var available: [InterleafIllustration] {
        let profiles = Dictionary(BookReferenceCatalog.labyrinthIllustrations.map { ($0.assetName, $0) }, uniquingKeysWith: { first, _ in first })
        let evergreen = BookReferenceCatalog.bundledCharacterIllustrationAssetNames.sorted().map { name in
            let profile = profiles[name]
            return InterleafIllustration(
                id: "evergreen::\(name)", assetName: name,
                title: profile?.title ?? "An illustration from the Labyrinth",
                tags: profile?.tags ?? ["illustration", "labyrinth"]
            )
        }
        let authored = PageArchetypePackRegistry.enabledPacks().flatMap { pack in
            (pack.interleafIllustrations ?? []).map { original in
                var plate = original
                plate.id = "pack::\(pack.id)::\(original.id)"
                return plate
            }
        }
            .filter { plate in
                let name = plate.resolvedAssetName
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !name.contains("{{asset-path:") else { return false }
                // Managed files must actually be installed. Catalogue names
                // are allowed for bundled pack art as in the existing cabinet.
                return !name.hasPrefix("/") || FileManager.default.fileExists(atPath: name)
            }
        var seen = Set<String>()
        return (authored + evergreen + permanentScenes).filter { seen.insert($0.resolvedAssetName).inserted }
    }
}

struct CharacterIllustrationProfile: Identifiable, Codable, Equatable {
    var id: String
    var characterName: String
    var slug: String
    var status: String
    var chapter: String?
    var core: String
    var signature: String
    var palette: String
    var silhouette: String
    var continuity: String
    var avoid: String
    var assetName: String?
    var intendedAssetName: String
    var prompt: String
    var negativePrompt: String
    var marginalia: [String]
    var tags: [String]

    var hasBundledAsset: Bool {
        assetName?.isEmpty == false
    }

    var illustrationDossierKind: String {
        if tags.contains("location") || status == "location" { return "Location dossier" }
        if tags.contains("book-fae") || status == "book-fae" { return "Book Fae dossier" }
        return "Character dossier"
    }

    var illustrationTag: String {
        if tags.contains("location") || status == "location" { return "location" }
        if tags.contains("book-fae") || status == "book-fae" { return "book-fae" }
        return "character"
    }
}

enum QuipPackAvailability: String, Codable, Equatable {
    case bundledFree
    case patron
    case paid
    case userImported
    case locked
}

struct QuipPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var quips: [QuipEntry]
}

/// The syntactic move a quip makes, worked out from the words rather than
/// stored on the entry.
///
/// The shelf grew into one joke told a hundred ways: "a NOUN is a NOUN that
/// VERBS". Every line was funny and the page still went flat, because a
/// surprise that arrives in the same shape every time is a format. Selection
/// reads this so one desk never carries two of the same move, and so the
/// quieter shapes — a dare, a question, a plain astonishing fact — get their
/// turn instead of losing to the wittiest equation in the pool.
enum QuipShape: String, Codable, Equatable, CaseIterable {
    /// "A mirror is an extremely punctual ghost."
    case equation
    /// "Bread goes stale from the outside. Cake goes stale from the inside."
    case observation
    /// "Go and look at the underside of a leaf."
    case dare
    /// "What did you walk past twice today?"
    case question
}

struct QuipEntry: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var title: String
    var tags: [String]
    var packID: String
    var weight: Int

    private static let imperatives: Set<String> = [
        "go", "look", "find", "put", "take", "watch", "hold", "say", "count",
        "smell", "touch", "ask", "turn", "stand", "step", "notice", "open",
        "listen", "pick", "check", "read", "carry", "keep", "leave"
    ]

    var shape: QuipShape {
        if text.contains("?") { return .question }
        let firstWord = text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .first
            .map(String.init) ?? ""
        if Self.imperatives.contains(firstWord) { return .dare }
        let equation = #"^(?:A|An|The)?\s*[A-Za-z][A-Za-z'\- ]{0,28}\s(?:is|are)\s(?:a|an|the|what|just|where|two|only|proof|time|air|enthusiasm|rain|privacy)\b"#
        if text.range(of: equation, options: .regularExpression) != nil { return .equation }
        return .observation
    }
}

/// A kept quotation: a line from a poet, scientist, filmmaker, or quiet noticer,
/// gathered onto the Quotes page. The Book carries these the way it carries the
/// Wonder Compass passages: as borrowed lanterns, always attributed, never
/// pretending they are the Book's own.
struct QuoteEntry: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var author: String
    /// The book, poem, film, or collection, when it is worth naming. Optional so
    /// aphorisms and attributed sayings can stand on the author alone.
    var source: String?
    /// A one-word shelf label: "Attention", "Wonder", "Impermanence": used as the
    /// card headline so the desk reads as a themed set, not a wall of text.
    var theme: String
    var tags: [String]
    var packID: String
    var weight: Int

    /// "Mary Oliver, Wild Geese" or, sourceless, "Rumi".
    var attributionLine: String {
        if let source, !source.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(author), \(source)"
        }
        return "\(author)"
    }
}

struct QuotePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var quotes: [QuoteEntry]
}

/// A small believing in the Book's own voice: child-like, never childish.
/// Gifts simply hand the reader something to carry; pacts propose a tiny
/// agreement and invite a countersignature in the ordinary margin note
/// ("I will.", "I agree.", or an honest "We'll see.").
struct AffirmationEntry: Identifiable, Codable, Equatable {
    var id: String
    /// The believing itself, spoken by the Book.
    var text: String
    /// A smaller second line under the believing: the Book's aside.
    var aside: String
    /// Tap-to-stamp phrases for the margin note. Pacts should always include a
    /// hedge ("We'll see.") so agreement stays honest, never extracted.
    var countersigns: [String]
    /// The margin-note placeholder, e.g. "I will…" for pacts.
    var placeholder: String
    /// One-or-two-word shelf label used as the card headline.
    var theme: String
    var tags: [String]
    var packID: String
    var weight: Int

    /// True when this believing asks for an agreement rather than only offering.
    var isPact: Bool {
        tags.contains("pact")
    }
}

struct AffirmationPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var affirmations: [AffirmationEntry]
}

enum SelfFactSensitivity: String, Codable, Equatable, CaseIterable {
    case identity
    case comfort
    case delight
    case values
    case story
}

enum SelfFactUsePermission: String, Codable, Equatable, CaseIterable {
    case privateContext
    case quoteAllowed
    case storyOnly
    case doNotUse
}

struct SelfFact: Identifiable, Codable, Equatable {
    var id: String
    var questionID: String
    var question: String
    var answer: String
    var bookTranslation: String
    var sensitivity: SelfFactSensitivity
    var usePermission: SelfFactUsePermission
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct AboutYouQuestion: Identifiable, Codable, Equatable {
    var id: String
    var packID: String
    var prompt: String
    var detail: String
    var placeholder: String
    var sensitivity: SelfFactSensitivity
    var defaultUsePermission: SelfFactUsePermission
    var tags: [String]
    var priority: Int
}

struct SelfKnowledgePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: ContentPackAvailability
    var questions: [AboutYouQuestion]
}

/// Only the coarse facts needed to decide whether one optional You Page would
/// materially improve the Curator's next choices. This is not a reader model
/// and contains no prose, coordinates, Calendar titles, or raw sensor values.
struct CausalColdStartQuestionContext: Equatable {
    var hasWeatherContext = false
    var hasPlaceContext = false
    var hasCalendarContext = false
    var hasCurrentState = false
    var qualifiedOutcomeCount = 0

    static let neutral = CausalColdStartQuestionContext()
}

enum SelfKnowledgePackRegistry {
    static let corePackID = "core-self-knowledge"
    /// You Pages are voluntary conversation, so the ceiling can be generous
    /// without turning them into onboarding. The Curator still decides whether
    /// an About You Page belongs on the desk at all.
    static let maxAboutYouFactsPerDay = 5
    static let minimumHoursBetweenAboutYouFacts = 1
    static let maxInterestFacts = 7

    static let bundledPacks: [SelfKnowledgePack] = [
        SelfKnowledgePack(
            id: corePackID,
            displayName: "Core Self-Knowledge Pack",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            questions: coreQuestions
        )
    ]

    static var enabledPacks: [SelfKnowledgePack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var questions: [AboutYouQuestion] {
        enabledPacks.flatMap(\.questions)
    }

    static func question(id: String) -> AboutYouQuestion? {
        questions.first { $0.id == id }
    }

    static let shadowTag = "shadow"
    static let darkPermissionQuestionID = "dark-permission"
    /// The Book has to prove it can hold small things before it asks for heavy
    /// ones. Twelve ordinary answers is roughly "we have been doing this a
    /// while and it hasn't been weird about any of it."
    static let shadowShelfUnlockFactCount = 12

    /// A reader who has already closed a door is not asked to open a different
    /// one. `story-no` answered as a hard refusal keeps the shadow shelf shut
    /// until they open it themselves.
    static func isShadowShelfUnlocked(knownFacts: [SelfFact]) -> Bool {
        let ordinary = knownFacts.filter { !$0.tags.contains(shadowTag) }
        guard ordinary.count >= shadowShelfUnlockFactCount else { return false }
        let refusedEverything = knownFacts.first { $0.questionID == "story-no" }.map { fact in
            let answer = fact.answer.lowercased()
            return ["everything", "all of it", "anything", "nothing is", "none of it"]
                .contains { answer.contains($0) }
        } ?? false
        return !refusedEverything
    }

    static func exampleLines(for question: AboutYouQuestion) -> [String] {
        suggestedAnswers[question.id] ?? []
    }

    static func choicePrompt(for question: AboutYouQuestion) -> String {
        question.id == "rut-signal" ? "WHICH LINE FOUND YOU?" : "A FEW ANSWERS TO TRY ON"
    }

    static func packName(for packID: String) -> String {
        enabledPacks.first { $0.id == packID }?.displayName ?? "the shelf"
    }

    static let causalColdStartQuestionOrder: [String] = [
        "wonder-entry",
        "time-budget",
        "leaving-home",
        "movement-access",
        "social-energy",
        "best-time",
        "energy-window",
        "sensory-door",
        "desired-surprise",
        "money-boundary",
        "favorite-weather",
        "favorite-kind-of-place",
        "transition-hard"
    ]
    static let causalColdStartQuestionIDs = Set(causalColdStartQuestionOrder)

    static func isCausalColdStartQuestion(_ questionID: String) -> Bool {
        causalColdStartQuestionIDs.contains(questionID)
    }

    /// Practical boundaries matter, but two intake-shaped questions in a row
    /// make the living Book sound like it has found a clipboard. After one
    /// operating-envelope answer, the next You Page must be something the
    /// reader may enjoy discovering about themselves.
    static func isBrightInterludeOwed(knownFacts: [SelfFact]) -> Bool {
        knownFacts
            .filter { question(id: $0.questionID) != nil }
            .max(by: { $0.createdAt < $1.createdAt })
            .map { isCausalColdStartQuestion($0.questionID) } ?? false
    }

    static func isBrightInterludeQuestion(_ question: AboutYouQuestion) -> Bool {
        guard !isCausalColdStartQuestion(question.id),
              !question.tags.contains(shadowTag),
              !question.tags.contains("boundary"),
              !question.tags.contains("constraint"),
              !question.tags.contains("rut") else {
            return false
        }
        let brightTags: Set<String> = [
            "delight", "wonder", "play", "mischief", "curiosity",
            "story-seed", "ritual", "object", "surprise"
        ]
        return !brightTags.isDisjoint(with: Set(question.tags))
    }

    static func nextQuestion(
        knownFacts: [SelfFact],
        day: BookDay,
        now: Date,
        coldStart: CausalColdStartQuestionContext = .neutral
    ) -> AboutYouQuestion? {
        let answered = Set(knownFacts.map(\.questionID))
        let answeredInterestCount = knownFacts.filter { $0.questionID.hasPrefix("interest-") }.count
        let knowsReaderName = knownFacts.contains { fact in
            fact.questionID == "name" || fact.tags.contains("name")
        }
        let shadowUnlocked = isShadowShelfUnlocked(knownFacts: knownFacts)
        let available = questions.filter { question in
            if question.id.hasPrefix("interest-") {
                guard answeredInterestCount < maxInterestFacts else { return false }
                if question.id == "interest-01" {
                    return !answered.contains(question.id)
                }
                let expectedID = String(format: "interest-%02d", answeredInterestCount + 1)
                return question.id == expectedID && !answered.contains(question.id)
            }
            if question.tags.contains(shadowTag) {
                guard shadowUnlocked else { return false }
                // Consent comes before the questions it governs.
                if question.id != darkPermissionQuestionID {
                    guard answered.contains(darkPermissionQuestionID) else { return false }
                }
            }
            return !answered.contains(question.id)
        }
        guard !available.isEmpty else { return nil }

        // The first interest is immediately useful across the whole Book:
        // especially The Bleed's Reader's Shelf. Once onboarding has supplied
        // a name, ask for one bright subject before returning to the slower
        // self-knowledge sequence. Later interests retain their gentle pace.
        if knowsReaderName,
           answeredInterestCount == 0,
           let firstInterest = available.first(where: { $0.id == "interest-01" }) {
            return firstInterest
        }

        let slot = SurfaceCadence.slotID(for: now, hours: 12)
        let seed = abs("\(day.id)-about-you-\(slot)".stableHash)

        if isBrightInterludeOwed(knownFacts: knownFacts),
           let bright = available
            .filter(isBrightInterludeQuestion)
            .max(by: { left, right in
                let leftScore = left.priority * 1000 + abs((seed ^ left.id.stableHash) % 997)
                let rightScore = right.priority * 1000 + abs((seed ^ right.id.stableHash) % 997)
                return leftScore < rightScore
            }) {
            return bright
        }

        // During causal cold start, ask the question most likely to change an
        // actual curation decision instead of simply walking the catalog in
        // authored order. These answers remain declared priors; only later
        // qualified lived outcomes count as causal evidence.
        let knownCurationAnswers = answered.intersection(causalColdStartQuestionIDs).count
        let hasInscriptionContext = knowsReaderName || knownFacts.contains {
            $0.questionID.hasPrefix("onboarding-") || $0.tags.contains("onboarding")
        }
        let isStillLearningTheOperatingEnvelope =
            hasInscriptionContext
                && (knownCurationAnswers < 6 || coldStart.qualifiedOutcomeCount < 3)
        let directedQuestions = available.filter {
            causalColdStartQuestionIDs.contains($0.id)
        }
        if isStillLearningTheOperatingEnvelope,
           let directed = directedQuestions.max(by: { left, right in
                coldStartQuestionValue(
                    left,
                    facts: knownFacts,
                    context: coldStart,
                    seed: seed
                ) < coldStartQuestionValue(
                    right,
                    facts: knownFacts,
                    context: coldStart,
                    seed: seed
                )
            }) {
            return directed
        }

        return available.sorted { left, right in
            let leftScore = left.priority * 1000 + abs((seed ^ left.id.stableHash ^ left.packID.stableHash) % 997)
            let rightScore = right.priority * 1000 + abs((seed ^ right.id.stableHash ^ right.packID.stableHash) % 997)
            return leftScore > rightScore
        }.first
    }

    private static func coldStartQuestionValue(
        _ question: AboutYouQuestion,
        facts: [SelfFact],
        context: CausalColdStartQuestionContext,
        seed: Int
    ) -> Int {
        let base: [String: Int] = [
            "wonder-entry": 980,
            "time-budget": 950,
            "leaving-home": 930,
            "movement-access": 910,
            "social-energy": 820,
            "best-time": 800,
            "energy-window": 790,
            "sensory-door": 760,
            "desired-surprise": 750,
            "money-boundary": 730,
            "favorite-weather": 700,
            "favorite-kind-of-place": 680,
            "transition-hard": 660
        ]
        var value = base[question.id] ?? 0
        let answers = Dictionary(
            facts
                .filter { $0.usePermission != .doNotUse }
                .map { ($0.questionID, $0.answer.lowercased()) },
            uniquingKeysWith: { _, latest in latest }
        )
        let alive = answers["onboarding-most-alive"] ?? ""
        let magic = answers["onboarding-magic-source"] ?? ""
        let rut = answers["onboarding-rut-strongest"] ?? ""

        if question.id == "favorite-weather",
           context.hasWeatherContext || magic.contains("weather") {
            value += 420
        }
        if question.id == "favorite-kind-of-place",
           context.hasPlaceContext || alive.contains("outside") || magic.contains("place") {
            value += 360
        }
        if question.id == "leaving-home",
           context.hasPlaceContext || alive.contains("outside") || alive.contains("movement") {
            value += 380
        }
        if question.id == "movement-access",
           alive.contains("movement") || alive.contains("outside") {
            value += 350
        }
        if question.id == "social-energy",
           alive.contains("people") || alive.contains("helping") || magic.contains("people") || magic.contains("laugh") {
            value += 390
        }
        if ["best-time", "energy-window", "time-budget", "transition-hard"].contains(question.id),
           context.hasCalendarContext || rut.contains("work") || rut.contains("later") {
            value += 280
        }
        if question.id == "time-budget", context.hasCurrentState {
            value += 180
        }
        if question.id == "sensory-door",
           magic.contains("music") || magic.contains("detail") {
            value += 240
        }
        if question.id == "wonder-entry",
           magic.contains("not sure") || magic.isEmpty {
            value += 300
        }

        // Stable variety only breaks genuine ties; authored/question value
        // remains legible in tests and in the Curator Observatory.
        value += abs((seed ^ question.id.stableHash) % 31)
        return value
    }

    static func translation(for question: AboutYouQuestion, answer: String) -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        // Shadow answers are received, not brightened. No thanks, no reframe, no
        // promise to make something lovely out of it: those are the reflexes
        // that make an app unsafe to tell a hard thing to. The Book says what it
        // will do with the answer and then stops talking.
        if question.tags.contains(shadowTag) {
            switch question.id {
            case darkPermissionQuestionID:
                return "This is the rule now, and it outranks anything I think would make a better page: \(trimmed)."
            case "hard-season":
                return "Noted as something you came through, in your words, past tense: \(trimmed)."
            case "carrying":
                return "I'll write knowing this is in the room. I won't bring it up, and I won't write as if it isn't there."
            case "person-missed":
                return "I'll be careful about them. If they ever come near a page, it will be because you put them there."
            case "went-quiet":
                return "Held open, not filed as finished."
            case "still-angry":
                return "Kept as it is. I won't sand it down into something more comfortable."
            case "got-wrong":
                return "Kept without a verdict attached."
            case "saying-fine":
                return "I'll leave this one alone unless you raise it."
            default:
                return "Kept as you said it."
            }
        }
        if question.tags.contains("earned-label") {
            return "I treat this as an earned working title, not a personality box: \(trimmed)."
        }
        if question.tags.contains("rut-signal") {
            return "I'll remember this as the first place the Rut sounded familiar: \(trimmed)."
        }
        if question.tags.contains("rut-depth") {
            return "I'll treat this as a weather report, not a diagnosis: \(trimmed)."
        }
        if question.tags.contains("rut-season") {
            return "I'll call this season \(trimmed) when it needs to name the gray without making it permanent."
        }
        if question.tags.contains("wonder-entry") {
            return "I'll start near \(trimmed) when wonder needs to feel easy."
        }
        if question.tags.contains("boundary") || question.tags.contains("constraint") {
            return "I'll treat this as a real edge, not a challenge to overcome: \(trimmed)."
        }
        if question.tags.contains("rhythm") || question.tags.contains("energy-window") {
            return "I'll keep this rhythm in mind when deciding what kind of Page can honestly fit: \(trimmed)."
        }
        if question.tags.contains("people") || question.tags.contains("company") {
            return "I'll use this to shape invitations involving other people without turning it into a rule: \(trimmed)."
        }
        switch question.sensitivity {
        case .identity:
            return "I may call you \(trimmed) when the page needs to remember who is holding it."
        case .comfort:
            return "I'll treat this as a signal for comfort, shelter, and the shape of gentleness."
        case .delight:
            if question.tags.contains("interest") {
                return "I'll keep this interest near the desk, ready to tint scenes, quips, and invitations."
            }
            return "I'll let this tint future pages when wonder needs a familiar spark."
        case .values:
            return "I'll give this belief weight when Story Pages choose what matters."
        case .story:
            return "I'll carry this as story-shape, not a box: a pattern to notice, not a verdict."
        }
    }

    private static let coreQuestions: [AboutYouQuestion] = [
        question("rut-signal", "Which 'ugh, that's me' line hit first?", "I'm not diagnosing you. I'm finding the door that already opened.", "Tap the line that found you first, or write your own.", .comfort, .privateContext, ["rut", "rut-signal", "wonder-compass", "self-recognition", "state-not-identity"], 96),
        question("rut-depth", "How loud is the Rut right now?", "Rough is enough. This is a weather report, not a tattoo.", "0-3: tired but functional. 4-7: in the rut. 8-10: whirlpool. 11-12: deep water.", .comfort, .privateContext, ["rut", "rut-depth", "wonder-compass", "self-recognition", "state-not-identity"], 95),
        question("rut-season", "What should we call this season?", "Naming it takes some of its teeth. Keep it small and honest.", "The Fog. Maintenance Mode. The Too-Many-Tabs Era. Getting Back to Color.", .comfort, .privateContext, ["rut", "rut-season", "wonder-compass", "self-recognition", "state-not-identity"], 94),
        question("wonder-entry", "What kind of wonder still works on you?", "Pick the door you'd actually open on a tired Tuesday.", "Looking out. Pocket adventure. Odd details. Color. Making. People. Quiet.", .delight, .privateContext, ["wonder", "wonder-compass", "wonder-entry", "wonder-affinity", "delight", "low-friction"], 93),
        question("home-place", "Where do you call home?", "A place can be true without being precise.", "A town, coast, room, region, or kind of place.", .comfort, .privateContext, ["home", "place"], 88),
        question("home-meaning", "What does home mean to you?", "Not the address. The feeling I should recognize.", "Safety, noise, chosen people, a porch light...", .comfort, .storyOnly, ["home", "meaning"], 84),
        question("favorite-color", "What color keeps finding you?", "I can tint future pages with a little more you in them.", "Blue, moss green, marigold, storm gray...", .delight, .privateContext, ["color", "delight"], 78),
        question("interest-01", "What's an interest of yours?", "I want to know what lights your shelves from the inside.", "Sailing, cooking, weird history, cozy games, old maps...", .delight, .privateContext, ["interest", "delight", "story-seed"], 77),
        question("interest-02", "What's another interest of yours?", "Interests make excellent doors. I'm collecting keys slowly.", "A hobby, subject, fandom, craft, place, creature, question...", .delight, .privateContext, ["interest", "delight", "story-seed"], 65),
        question("interest-03", "What's another interest of yours?", "A second shelf has opened. Put one bright thing on it.", "Something you read about, make, watch, collect, or chase...", .delight, .privateContext, ["interest", "delight", "story-seed"], 64),
        question("interest-04", "What's another interest of yours?", "I'm learning what kinds of doors you notice first.", "A world, practice, problem, texture, tool, era, mystery...", .delight, .privateContext, ["interest", "delight", "story-seed"], 63),
        question("interest-05", "What's another interest of yours?", "Some interests are lanterns. Some are secret staircases.", "Tiny, grand, serious, silly. All of them count.", .delight, .privateContext, ["interest", "delight", "story-seed"], 62),
        question("interest-06", "What's another interest of yours?", "I'm nearly done filling this shelf.", "A thing you could talk about for ten minutes too long...", .delight, .privateContext, ["interest", "delight", "story-seed"], 61),
        question("interest-07", "What's one last interest for this shelf?", "Seven is plenty. I can make a map from here.", "One more spark. Anything at all.", .delight, .privateContext, ["interest", "delight", "story-seed"], 60),
        question("small-delight", "What small thing reliably delights you?", "A tiny delight is a strong lantern.", "A food, sound, texture, joke, place, creature...", .delight, .privateContext, ["delight", "wonder"], 76),
        question("rest-shape", "What does real rest look like for you?", "I should learn the difference between rest and merely stopping.", "Quiet, movement, sleep, music, being left alone...", .comfort, .privateContext, ["rest", "care"], 72),
        question("belief", "What do you believe in, even on tired days?", "One sturdy sentence for the shelf.", "Kindness, curiosity, making things, second chances...", .values, .storyOnly, ["values", "belief"], 68),
        question("protect", "What do you protect?", "I need to know what's heavy, so I don't drop it.", "People, time, wonder, honesty, softness, the work...", .values, .storyOnly, ["values", "protection"], 62),
        question("becoming", "What kind of person are you trying to become?", "Not as homework. As a north star.", "Braver, gentler, more alive, less hidden...", .values, .storyOnly, ["growth", "values"], 58),
        question("story-role", "What role do you usually play in a group?", "Every story needs a scout, a joker and a worrier. I want to know which chair you sit in.", "Guide, comic relief, caretaker, scout, skeptic...", .story, .storyOnly, ["story", "role"], 52),
        question("favorite-weather", "What weather makes you more yourself?", "Not the weather you're supposed to like. The one that makes you feel more alive.", "Cold sun. Thunder. First snow. Rain against a window...", .delight, .privateContext, ["weather", "delight", "wonder-affinity"], 75)
        ,question("sensory-door", "Which sense finds wonder first for you?", "I'll knock on that door first.", "Sound. Color. Texture. Smell. Taste. Movement...", .delight, .privateContext, ["sense", "wonder-affinity", "curation"], 74)
        ,question("best-time", "What part of the day still feels like yours?", "The clock and your life aren't always telling the same story.", "Early morning. Lunch. Dusk. After everyone sleeps...", .comfort, .privateContext, ["rhythm", "energy-window", "time"], 73)
        ,question("energy-window", "When does a little adventure feel easiest?", "I'd rather knock when the door's already open.", "Before work. On lunch. After dinner. Weekends. It changes...", .comfort, .privateContext, ["rhythm", "energy-window", "curation"], 72)
        ,question("ordinary-ritual", "What tiny habit already makes a day feel like yours?", "I'm very interested in ceremonies nobody else knows are ceremonies.", "A certain mug. Music while cooking. Walking the long way...", .delight, .storyOnly, ["habit", "delight", "daily-life"], 71)
        ,question("comfort-object", "Which ordinary object has quietly joined your side?", "Some objects have already joined the Cast without filling out the forms.", "A blanket. A pen. A battered pan. The chair by the window...", .delight, .storyOnly, ["object", "comfort", "animism", "story-seed"], 70)
        ,question("small-luxury", "What tiny luxury works embarrassingly well on you?", "No defense is required. Delight has terrible taste and excellent instincts.", "Fancy soap. The good cup. Hotel sheets. Fries in the car...", .delight, .privateContext, ["delight", "comfort", "low-friction"], 69)
        ,question("tiny-mischief", "What harmless rule do you most enjoy bending?", "I need to know where your grin keeps its spare key.", "Dessert first. Taking the scenic route. Reading past bedtime...", .story, .storyOnly, ["mischief", "play", "dehabituation", "story-seed"], 68)
        ,question("secret-skill", "What are you oddly good at?", "Not résumé good. The peculiar competency friends discover by accident.", "Packing a car. Finding the best thing on a menu. Naming dogs...", .delight, .storyOnly, ["skill", "identity", "story-seed"], 67)
        ,question("unfinished-curiosity", "What question has followed you for years?", "An unanswered question can be a room rather than a problem.", "A family mystery. How birds navigate. What makes a place feel sacred...", .story, .storyOnly, ["curiosity", "question", "story-seed"], 66)
        ,question("favorite-kind-of-place", "What kind of place makes you look up?", "I want the kind of place, not the address.", "Old libraries. Diners. Harbors. Hardware stores. Deep woods...", .delight, .privateContext, ["place", "wonder-affinity", "curation"], 65)
        ,question("place-to-return", "Where would you happily go for no efficient reason?", "A useful place gets errands. A beloved place keeps calling after the errands are dead.", "A bench. A bookstore. A neighborhood. A stretch of water...", .delight, .privateContext, ["place", "return", "delight"], 64)
        ,question("person-laugh", "Who changes the sound of your laugh?", "I don't need their whole biography. Just the kind of gravity they alter.", "A friend. A sibling. A coworker. Someone no longer nearby...", .identity, .privateContext, ["people", "relationship", "delight"], 63)
        ,question("person-adventure", "Who would understand a very small adventure?", "Company changes what a door costs to open.", "Someone specific. Whoever is free. Nobody: I like going alone...", .identity, .privateContext, ["people", "company", "wonder-compass"], 62)
        ,question("care-language", "How can someone make you feel cared for without making a speech?", "Small proof beats big speeches.", "Bring food. Remember a detail. Sit nearby. Make me laugh...", .comfort, .storyOnly, ["people", "care", "relationship"], 61)
        ,question("social-energy", "When wonder appears, do you want company?", "The honest answer may change by day. Give me the usual weather.", "Usually alone. One person. A small group. Whoever is already there...", .comfort, .privateContext, ["people", "company", "social", "curation"], 60)
        ,question("alone-shape", "What kind of being alone feels good?", "Solitude and isolation wear similar coats. I should learn the difference.", "Making something. Wandering. Reading near other people. Complete quiet...", .comfort, .storyOnly, ["solitude", "comfort", "rest"], 59)
        ,question("weekend-texture", "What should a good free afternoon feel like?", "Not what it should accomplish. What texture tells you it belonged to you?", "Spacious. Playful. Unplanned. Productive in a satisfying way...", .delight, .privateContext, ["rhythm", "weekend", "delight"], 58)
        ,question("transition-hard", "Which bit of an ordinary day is the greyest?", "I'll ask for less around then.", "Waking up. Getting home. Starting dinner. Sunday evening...", .comfort, .privateContext, ["rhythm", "transition", "constraint", "curation"], 57)
        ,question("leaving-home", "How do you feel about me sending you out of the house?", "Going out isn't always the right door. Tell me how often it is.", "Send me out. Ask first. Only when I choose. Keep the magic indoors...", .comfort, .privateContext, ["boundary", "constraint", "home", "curation"], 56)
        ,question("movement-access", "Is there anything I should know before I send you somewhere?", "I'll take it as plain fact, not poetry.", "Short distances. Somewhere to sit. No stairs. Anything goes. Ask each time...", .comfort, .privateContext, ["boundary", "constraint", "access", "curation"], 55)
        ,question("time-budget", "How much time can a tiny adventure usually borrow?", "I'd rather fit inside ten honest minutes than invent an imaginary afternoon.", "One minute. Ten minutes. Half an hour. It depends on the day...", .comfort, .privateContext, ["boundary", "constraint", "time", "curation"], 54)
        ,question("money-boundary", "Should my errands ever cost money?", "Magic shouldn't need a shop. Tell me where your line is.", "Free, always. A few coins is fine. Ask first. Spending is fine...", .comfort, .privateContext, ["boundary", "constraint", "budget", "curation"], 53)
        ,question("story-no", "Is there anything I should never put in a story?", "A closed door is useful to know about. I won't rattle it.", "Work. Family. Health. A person. Nothing comes to mind yet...", .comfort, .doNotUse, ["boundary", "story", "privacy"], 52)
        ,question("childhood-wonder", "What fascinated you before usefulness got involved?", "Children notice doors that grown-ups paint over later.", "Rocks. Ghost stories. Trains. Drawing maps. Taking things apart...", .story, .storyOnly, ["childhood", "wonder", "story-seed"], 51)
        ,question("lost-interest", "What did you once love that's gone quiet?", "I might remember it. I won't make you take it up again.", "A craft. A game. A subject. A place. A version of going out...", .story, .storyOnly, ["interest", "return", "memory"], 50)
        ,question("desired-surprise", "What kind of surprise almost always works on you?", "Surprise comes in flavours. I want to know yours.", "A strange fact. A beautiful place. A joke. A message. A tiny challenge...", .delight, .privateContext, ["surprise", "wonder-affinity", "curation"], 49)
        ,question("current-question", "What are you quietly trying to understand lately?", "It doesn't have to be a goal. Questions can just colour the margins.", "A relationship. A decision. A craft. My own attention. Something unnamed...", .story, .storyOnly, ["question", "current-season", "story-seed"], 48)
        ,question("life-chapter", "If this stretch of life had a chapter title, what would it be?", "Working title only. I own an eraser.", "The Rebuilding. Too Many Tabs. Learning the Coastline. Intermission...", .story, .storyOnly, ["current-season", "story", "state-not-identity"], 47)
        ,question("thing-not-to-optimize", "What part of life do you refuse to optimize?", "Excellent. Efficiency has been getting above itself.", "Cooking. Friendship. Reading. Wandering. The way I make coffee...", .values, .storyOnly, ["values", "dehabituation", "protection"], 46)
        ,question("favorite-object", "What object would you save for sentimental reasons?", "It'll tell me things usefulness never could.", "A letter. A chipped bowl. A coat. A tool. Something ridiculous...", .story, .storyOnly, ["object", "memory", "story-seed"], 45)
        // The Book keeps the whole world's calendar and would rather not miss
        // the one day on it that is actually about the reader. Month and day
        // only: it asks for no year and stores none.
        ,question("reader-birthday", "When's your birthday? Month and day.", "Don't give me the year. I'm not interested in how old you are, I'm interested in the date.", "March 3rd. 14 August. The eleventh of November...", .delight, .privateContext, ["birthday", "calendar", "celebration"], 55)

        // MARK: The shadow shelf
        //
        // For a long time this registry only measured light: delight, wonder,
        // rest, mischief, color, and so the Book could only ever tell half a
        // life. These are the other half.
        //
        // They are deliberately unlike everything above: no example answers (you
        // do not offer someone multiple choice for grief), the lowest priorities
        // in the shelf so they arrive long after the ordinary questions, and a
        // maturity gate in `nextQuestion` so the Book has to prove it can hold
        // small things before it asks for heavy ones. Most are past tense:
        // asking what someone came through is a different act from asking what
        // they are currently inside.
        ,question("hard-season", "What's a stretch you came through that changed you?", "Past tense only. If it's still going on, shut this little door. I won't reach in.", "Four words will do. Or close the little door. I won't pick the lock.", .story, .storyOnly, ["shadow", "past", "story-seed", "state-not-identity"], 24)
        ,question("carrying", "What are you carrying at the moment?", "Put it down, explain it, or do neither. I only want to know where not to step.", "One word, a paragraph, or leave the line staring back.", .comfort, .storyOnly, ["shadow", "present", "care"], 23)
        ,question("person-missed", "Who do you miss?", "Missing someone isn't only for the dead: distance and estrangement count.", "A name, or just who they were to you.", .comfort, .storyOnly, ["shadow", "people", "absence"], 22)
        ,question("went-quiet", "What ended that you haven't finished with?", "Things end long before we're done with them. That gap is worth knowing about.", "A friendship, a job, a place, a version of yourself.", .story, .storyOnly, ["shadow", "absence", "unfinished"], 21)
        ,question("still-angry", "What still makes you angry?", "Anger is information. I won't try to talk you out of it, or call it growth.", "Something done to you, something you watched happen, something ongoing.", .values, .storyOnly, ["shadow", "anger", "values"], 20)
        ,question("got-wrong", "What did you get wrong that still sits with you?", "I'm not here to forgive you. I'm just nosy about what stuck.", "Give me the outline and keep the teeth.", .story, .storyOnly, ["shadow", "regret", "state-not-identity"], 19)
        ,question("saying-fine", "What do you say you're fine about?", "I know better than to poke that bruise first. You name it or it keeps its coat on.", "The thing with the short, practiced answer.", .comfort, .storyOnly, ["shadow", "present", "unsaid"], 18)
        ,question("dark-permission", "How should I handle the heavy things you tell me?", "This one changes what I do, so it outranks my curiosity.", "Keep it in mind but never write it. Let it into stories once it's old. Ask me each time.", .comfort, .privateContext, ["shadow", "boundary", "consent", "privacy"], 25)
    ]

    private static let suggestedAnswers: [String: [String]] = [
        "rut-signal": [
            "Whole weeks are happening, but I couldn't tell you what I did.",
            "I keep opening my phone without knowing why.",
            "Figuring out dinner feels like a major administrative task.",
            "When plans get canceled, relief arrives before disappointment.",
            "Things I usually like feel weirdly flavorless."
        ],
        "wonder-entry": ["Odd details", "A pocket adventure", "Making something", "People", "Quiet"],
        "favorite-weather": ["Cold bright sun", "Rain against a window", "A thunderstorm", "The first real snow", "Warm wind after dark"],
        "sensory-door": ["Sound", "Color", "Texture", "Smell", "Movement"],
        "best-time": ["Early morning", "The middle of the day", "Dusk", "Late night", "It changes"],
        "energy-window": ["Before work", "At lunch", "After dinner", "Weekends", "It changes too much to name"],
        "social-energy": ["Usually alone", "With one person", "With a small group", "Whoever is already there", "Ask me that day"],
        "leaving-home": ["Usually welcome", "Ask gently", "Only when I choose it", "Keep wonder indoors", "It depends on the day"],
        "movement-access": ["Short distances", "Seated options", "No stairs", "Movement is welcome", "Ask me each time"],
        "time-budget": ["One minute", "Ten minutes", "Half an hour", "A whole afternoon", "Ask me that day"],
        "money-boundary": ["Free by default", "A few dollars is fine", "Ask first", "Spending is welcome", "It depends"],
        "desired-surprise": ["A strange fact", "A beautiful place", "A joke", "A message from someone", "A tiny challenge"],
        // The only shadow question with answers to try on, because it is a
        // consent choice rather than an invitation to open anything.
        "dark-permission": [
            "Know it, never write it",
            "Only once it's old",
            "Ask me each time",
            "You can use it"
        ]
    ]

    private static func question(
        _ id: String,
        _ prompt: String,
        _ detail: String,
        _ placeholder: String,
        _ sensitivity: SelfFactSensitivity,
        _ permission: SelfFactUsePermission,
        _ tags: [String],
        _ priority: Int
    ) -> AboutYouQuestion {
        AboutYouQuestion(
            id: id,
            packID: corePackID,
            prompt: prompt,
            detail: detail,
            placeholder: placeholder,
            sensitivity: sensitivity,
            defaultUsePermission: permission,
            tags: tags,
            priority: priority
        )
    }
}

// MARK: - The Reader's Role
//
// The Book names the reader on night one and means it. This is deliberately
// NOT the "state, not identity" register the Rut questions use: a Rut depth is
// weather and stays weather, but the role is an identity the reader is invited
// to want. It is composed from three answers they actually gave, so the
// uncanny specificity is earned rather than invented:
//
//   ROLE      what you do about the grey   (12, from most-alive x magic-source)
//   EPITHET   where the grey gets in       (6,  from the Rut question)
//   HANDS     what you do with what you find (5, its own onboarding question)
//
// Twelve times six times five is 360 distinct readings authored out of 23
// pieces. Every part is traceable to a sentence the reader typed or a chip they
// tapped; the Book never claims anything it was not told.

/// One structural role. Carries everything downstream needs: curation weight,
/// a compass line, the Cast member who sponsors it, and the flattering
/// definition the reader is handed on night one.
struct ReaderRole: Equatable {
    var id: String
    /// "The Magpie": always with the article, it is a title not an adjective.
    var name: String
    /// "Magpie". The article reads well in isolation and badly inside a longer
    /// phrase ("The Lookout Week"), so anything compositional uses this.
    var bareName: String {
        name.hasPrefix("The ") ? String(name.dropFirst(4)) : name
    }
    /// One line. The definition, stated as fact.
    var gloss: String
    /// Two or three sentences of the persona itself: what this is good at, what
    /// most people mistake it for, and why the Book wants it. Flattery is the
    /// point, but it has to be flattery the reader recognises.
    var dossier: String
    /// The pull this role feels, used on Compass Runs and missions.
    var compassLine: String
    /// What this reader does, already in the third person ("keeps the light
    /// low") so prose can drop it straight into a sentence. Do not append an "s".
    var verb: String
    var scoreBoosts: [BookPageType: Int]
    /// The Cast member who sponsors this role in the Labyrinth. Any of the
    /// dossiered cast, chosen for lore fit.
    var patronSlug: String
    var patronName: String
    /// The nearest cast member who actually has a `MarginVoices` voice, so the
    /// patron beat can be *spoken* even when the lore patron is silent. Roles
    /// may share one; this is "who sounds most like your patron", not a claim.
    var voiceSlug: String
    /// Onboarding `mostAlive` ids this role answers to. Worth `aliveWeight`.
    var aliveAffinity: [String]
    /// Onboarding `magicSource` ids this role answers to. Worth `magicWeight`.
    var magicAffinity: [String]
    /// Weaker pulls, worth one point, used to break ties sensibly rather than
    /// alphabetically.
    var secondaryAffinity: [String]

    var metadata: [String: String] {
        [
            // Legacy keys, still read by pages minted before the role existed.
            "wonderTitleID": id,
            "wonderTitleName": name,
            "wonderTitleCompassLine": compassLine,
            "readerRoleID": id,
            "readerRoleName": name,
            "readerRolePatron": patronSlug
        ]
    }
}

/// Where the grey gets in, named as a place rather than a failing. Half the
/// flattery is refusing to treat the Rut as the reader's fault.
struct RoleEpithet: Equatable {
    var id: String
    /// "of the Blue Hour": reads directly after the role name.
    var phrase: String
    /// What the Book says this particular grey costs the reader.
    var cost: String
}

/// What the reader's hands do with something good once they have found it.
/// The one axis that is asked outright, because it is the one that changes what
/// the Book should hand them next.
struct RoleHands: Equatable {
    var id: String
    /// "Telling Hands".
    var name: String
    var gloss: String
    var scoreBoosts: [BookPageType: Int]
}

/// A role, an epithet and a pair of hands, resolved together.
struct ComposedRole: Equatable {
    var role: ReaderRole
    var epithet: RoleEpithet?
    var hands: RoleHands?
    /// What the Book watched them do. Absent until it has watched anything.
    var mark: RoleMark?

    /// "The Magpie of the Blue Hour". The name the Book uses out loud.
    var fullName: String {
        guard let epithet else { return role.name }
        return "\(role.name) \(epithet.phrase)"
    }

    /// The complete three-part reading, for the reveal card and the colophon.
    var signature: String {
        guard let hands else { return fullName }
        return "\(fullName), with \(hands.name)"
    }

    var compassLine: String { role.compassLine }

    /// Curation weight is the role plus the hands: what you are drawn to, and
    /// what you do about it once you have it.
    var scoreBoosts: [BookPageType: Int] {
        var boosts = role.scoreBoosts
        for (type, boost) in hands?.scoreBoosts ?? [:] {
            boosts[type, default: 0] += boost
        }
        return boosts
    }

    /// "The Maker of the Blue Hour, Clear-Eyed": the Mark last, because it is
    /// the part the Book earned rather than was given.
    var titledName: String {
        guard let mark else { return fullName }
        return "\(fullName), \(mark.name)"
    }

    var metadata: [String: String] {
        var data = role.metadata
        data["readerRoleFullName"] = fullName
        data["readerRoleSignature"] = signature
        if let epithet { data["readerRoleEpithet"] = epithet.id }
        if let hands { data["readerRoleHands"] = hands.id }
        if let mark { data["readerRoleMark"] = mark.id }
        return data
    }
}

/// The three answers a role is read from. Any may be missing: a reader who
/// skipped a step still gets named, just less precisely.
struct RoleAxes: Equatable {
    /// Onboarding `rutStrongest` id, or a free-text Rut signal from the shelf.
    var rut: String?
    /// Onboarding `mostAlive` id. The spine of the role: whatever the reader
    /// says they come alive doing is what the role is *about*. The Book does
    /// not infer a different activity from it.
    var alive: String?
    /// Onboarding `magicSource` id, or a `wonder-entry` answer from the shelf.
    /// Colours the role; never renames it.
    var magic: String?
    /// Onboarding `hands` id.
    var hands: String?

    // MARK: What the Book watched, rather than what it was told
    //
    // Everything above is self-report, and self-report is what made the first
    // taxonomy easy to argue with. These are things the reader *did* while the
    // Book was in the room, and they are the only basis on which it claims to
    // have observed anything.

    /// Recall probes kept, 0...3. Measured attention.
    var recallKept: Int?
    /// Whether they caught the word the living ink took.
    var caughtTheWord: Bool?
    /// Whether they kept their first Page rather than letting it wait.
    var keptFirstPage: Bool?
    /// Whether they spent Belief on the thing they said they believed.
    var backedTheirBelief: Bool?
    /// Whether the Wicker exchange went their way.
    var heldAgainstWicker: Bool?

    var isEmpty: Bool {
        rut == nil && alive == nil && magic == nil && hands == nil
            && recallKept == nil && caughtTheWord == nil && keptFirstPage == nil
            && backedTheirBelief == nil && heldAgainstWicker == nil
    }

    /// True when the Book has watched enough to earn a Mark.
    var hasMeasuredEvidence: Bool {
        recallKept != nil || caughtTheWord != nil || keptFirstPage != nil
            || backedTheirBelief != nil || heldAgainstWicker != nil
    }
}

/// Something the Book *saw*, as opposed to something it was told. Marks are the
/// honest half of the naming: every one of them reports a thing that actually
/// happened during the Inscription, so none of them can be argued with.
struct RoleMark: Equatable {
    var id: String
    /// "Clear-Eyed". Sits after the role name.
    var name: String
    /// What the Book watched, said plainly enough that the reader recognises
    /// the moment being referred to.
    var evidence: String
}

struct WonderTitle: Equatable {
    var id: String
    var name: String
    var why: String
    var compassLine: String
    var scoreBoosts: [BookPageType: Int]

    var metadata: [String: String] {
        [
            "wonderTitleID": id,
            "wonderTitleName": name,
            "wonderTitleCompassLine": compassLine
        ]
    }
}

enum ReaderRoleRegistry {
    /// Weights for reading a role. What you *do* when you are most alive counts
    /// for more than what charms you: a maker who loves thunderstorms is a
    /// Mender, not a Weather Witch.
    static let aliveWeight = 3
    static let magicWeight = 2
    static let secondaryWeight = 1

    static let roleFactID = "reader-role"
    static let refusedFactID = "reader-role-refused"
    static let handsFactID = "onboarding-hands"

    /// One role per way of coming alive, and no more.
    ///
    /// The first taxonomy had twelve roles reverse-fitted to characters I
    /// wanted to write: "making something" produced The Mender, who fixes
    /// broken handles. A reader who makes things and never repairs anything
    /// was told a flat falsehood about themselves on night one, and correctly
    /// stopped believing the rest.
    ///
    /// So: the role restates the trigger. `mostAlive` is the spine, one role
    /// each, and the claim never migrates to a neighbouring activity. Magic
    /// colours the dossier; it does not rename anybody. Anything the Book
    /// asserts beyond "you told me this" has to come from a Mark, which
    /// reports something it actually watched.
    ///
    /// Dossiers are the Book naming who you are, with authority, through
    /// ordinary things: a pie, a heron, a friend's joke. bj chose the role as
    /// an identity claim (see the reader-role notes); a dossier may flatter.
    /// It says what that kind of person does, never a biographical fact that
    /// could be checked and found false.
    static let all: [ReaderRole] = [
        ReaderRole(
            id: "maker",
            name: "The Maker",
            gloss: "You come alive with something half-finished in front of you.",
            dossier: """
            Makers leave the world with a bit more in it than they found. A pie with a thumbprint in the crust. A chair that wobbled until Tuesday. A sentence you kept poking until it finally sat up straight.

            In my stories, Makers get handed the broken things, because they can't leave them alone. I'll bring you small things to make, and you bring me back what happened, especially the bit that went wrong. That's my favourite bit. Wrong bits have the best stories in them.
            """,
            compassLine: "Make one small thing that wasn't there this morning.",
            verb: "makes things",
            scoreBoosts: [.enchantment: 10, .bindery: 6, .academyClass: 6, .gamePage: 5, .wonderCompass: 4],
            patronSlug: "orion-blackthorn",
            patronName: "Orion Blackthorn",
            voiceSlug: "lydia-boggle",
            aliveAffinity: ["making"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "lookout",
            name: "The Lookout",
            gloss: "You come alive outdoors, where the weather can get at you.",
            dossier: """
            Lookouts are the first to see the sky change its mind. The heron on the fence post. The cold that turns up before the forecast does. The one leaf that's gone red early, showing off.

            In my stories, Lookouts get the high windows and the rooftops, where the weather comes to talk. I'll give you things to watch for on your way somewhere, and you tell me what was really out there. The weather doesn't have to behave. I'd honestly rather it didn't.
            """,
            compassLine: "Get outside for as long as it takes to notice one thing.",
            verb: "goes outside",
            scoreBoosts: [.weather: 10, .todaysSky: 8, .location: 7, .anchor: 6, .wonderCompass: 5],
            patronSlug: "zara-finch",
            patronName: "Zara Finch",
            voiceSlug: "zara-finch",
            aliveAffinity: ["outside"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "porchlight",
            name: "The Porchlight",
            gloss: "You come alive with your people in the room.",
            dossier: """
            Porchlights keep the good bits of other people. The joke at dinner that made someone snort their tea. The friend who remembers how you take yours. The voice you're always glad to hear.

            In my stories, a Porchlight is the reason everyone keeps drifting back to the kitchen. I'll bring you little questions about your people, and you bring me something one of them actually said. I can't make up their best lines. I've tried. Mine are worse.
            """,
            compassLine: "Let one thread point toward a person. Tiny contact counts.",
            verb: "keeps people close",
            scoreBoosts: [.letter: 10, .supportGuild: 7, .gossip: 6, .castBond: 5, .aboutYou: 4],
            patronSlug: "ambrose-trencher",
            patronName: "Ambrose Trencher",
            voiceSlug: "serenity-brown",
            aliveAffinity: ["people"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "detourist",
            name: "The Detourist",
            gloss: "You come alive moving, and preferably the long way.",
            dossier: """
            Detourists take the other street. The new lunch. The turn everyone else walks straight past, just to see what's down there. Mostly it's only a street. Sometimes it's a bakery, or a cat, or a gate painted a colour gates aren't meant to be.

            In my stories, Detourists find the corridors that weren't on the map yesterday. I'll suggest small adventures that fit an ordinary day, and you go and look. Getting there's your job. I haven't got sensible shoes. I haven't got feet either, which doesn't help.
            """,
            compassLine: "Go the wrong way on purpose and see what's down there.",
            verb: "takes the long way",
            scoreBoosts: [.wonderCompass: 10, .anchor: 8, .location: 7, .souvenir: 4],
            patronSlug: "lysander-mosswood",
            patronName: "Lysander Mosswood",
            voiceSlug: "wicker-eddies",
            aliveAffinity: ["movement"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "rabbit-holer",
            name: "The Rabbit-Holer",
            gloss: "You come alive with a question you can't put down.",
            dossier: """
            Rabbit-Holers can't leave a question alone. Why does that bird do that? Who named this street, and were they cross about something? Four hours later a Rabbit-Holer knows everything about canal locks and isn't one bit sorry.

            In my stories, Rabbit-Holers get the keys to the rooms with the dustiest books, where the questions breed. I'll bring you things to investigate, and you decide how far down to go. Bring me back one thing you found out. I'll almost certainly have another question. I always do.
            """,
            compassLine: "Pick the question you keep circling and give it one honest hour.",
            verb: "follows questions down",
            scoreBoosts: [.academyClass: 9, .lore: 8, .elective: 7, .facultyResearch: 6, .askTheBook: 5],
            patronSlug: "soren-ng",
            patronName: "Soren Ng",
            voiceSlug: "professor-thaddeus-mook",
            aliveAffinity: ["learning"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "nightlight",
            name: "The Nightlight",
            gloss: "You come alive when nobody needs anything from you.",
            dossier: """
            Nightlights know the good kind of quiet. The first cup of tea before anyone's up. An empty room with the lamp on. A whole minute when nobody needs an answer from you.

            In my stories, Nightlights get the library after closing, when the books whisper and the candles keep their own hours. I'll offer you Pages for that sort of time: one small thing to notice, and a place to write it down. I'll keep the louder characters busy. Wicker can't whisper. I've checked.
            """,
            compassLine: "Take the hour nobody's asking for. Don't fill it.",
            verb: "keeps their own company",
            scoreBoosts: [.rest: 10, .mood: 7, .bookPocket: 5, .diary: 5, .wonderCompass: 4],
            patronSlug: "professor-cedric-stonebrook",
            patronName: "Professor Stonebrook",
            voiceSlug: "dr-inkrest",
            aliveAffinity: ["solitude"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "steady-hand",
            name: "The Steady Hand",
            gloss: "You come alive when somebody's leaning on you and it holds.",
            dossier: """
            Steady Hands notice who could use a hand. The heavy bag on the stairs. The soup made for someone who's poorly. The friend who's had a rotten day and just needs somebody to listen for a bit.

            In my stories, a Steady Hand is who everyone looks for when the staircases start moving. I'll bring you small invitations about care and company, and you decide how much you've got to give that day. Some days the most useful thing a Steady Hand can do is ask for a hand back. I'll remind you. I'm annoying like that.
            """,
            compassLine: "Do the small useful thing before anybody asks for it.",
            verb: "shows up for people",
            scoreBoosts: [.supportGuild: 9, .letter: 8, .castBond: 6, .aboutYou: 5, .body: 4],
            patronSlug: "min-seo-kim",
            patronName: "Min-seo Kim",
            voiceSlug: "serenity-brown",
            aliveAffinity: ["helping"],
            magicAffinity: [],
            secondaryAffinity: []
        ),
        ReaderRole(
            id: "stowaway",
            name: "The Stowaway",
            gloss: "You come alive inside a story that isn't yours.",
            dossier: """
            Stowaways go somewhere when they read. A book on the bus that makes you miss your stop. A film that follows you home. A song you play again, and again, and once more for luck.

            In my stories, Stowaways are the ones who climb inside the tale and change it from the inside. I'll bring you people to meet and stories to take part in, and you choose what to do in them. I might argue with your decisions. I'll keep every one of them anyway, in ink.
            """,
            compassLine: "Go back into the one that got you. Bring something out.",
            verb: "gets lost in stories",
            scoreBoosts: [.narrativeOS: 9, .bookJump: 8, .quotes: 6, .radio: 5, .bookOfYou: 5],
            patronSlug: "professor-permancer",
            patronName: "Professor Permancer",
            voiceSlug: "gwendolyn-mythwright",
            aliveAffinity: ["story"],
            magicAffinity: [],
            secondaryAffinity: []
        )
    ]

    /// What the Book watched. Ordered by how much it took to earn: the first
    /// match wins, so a reader who did several gets credited for the hardest.
    static let marks: [RoleMark] = [
        RoleMark(
            id: "clear-eyed",
            name: "Clear-Eyed",
            evidence: "You kept all three of the small things I asked about. Almost nobody does."
        ),
        RoleMark(
            id: "unbowed",
            name: "Unbowed",
            evidence: "Wicker went at you on your first night in and you didn't give him anything."
        ),
        RoleMark(
            id: "quick",
            name: "Quick",
            evidence: "You caught the word I took while you were holding the Page."
        ),
        RoleMark(
            id: "backer",
            name: "Backer",
            evidence: "You put Belief behind what you said you believed, before it had done a day's work for you."
        ),
        RoleMark(
            id: "keeper",
            name: "Keeper",
            evidence: "You kept your first Page instead of letting it wait."
        ),
        RoleMark(
            id: "straight",
            name: "Straight-Dealing",
            evidence: "You told me what you'd actually lost rather than the flattering version. That's rarer than remembering."
        )
    ]

    static func mark(id: String) -> RoleMark? { marks.first { $0.id == id } }

    /// The Mark the reader earned, or nil when the Book has not watched them do
    /// anything yet. Never invents one: a Mark that was not earned is exactly
    /// the kind of claim that made the last taxonomy easy to dismiss.
    static func earnedMark(axes: RoleAxes) -> RoleMark? {
        guard axes.hasMeasuredEvidence else { return nil }
        if axes.recallKept == 3 { return mark(id: "clear-eyed") }
        if axes.heldAgainstWicker == true { return mark(id: "unbowed") }
        if axes.caughtTheWord == true { return mark(id: "quick") }
        if axes.backedTheirBelief == true { return mark(id: "backer") }
        if axes.keptFirstPage == true { return mark(id: "keeper") }
        // Everyone else told the truth about losing an hour, which the Book
        // refuses to treat as a failure state.
        return mark(id: "straight")
    }

    /// Where the grey gets in. Ordered to match the onboarding `rutChoices`.
    static let epithets: [RoleEpithet] = [
        RoleEpithet(
            id: "work",
            phrase: "of the Long Commute",
            cost: "The hours between your door and your desk go first. They always do."
        ),
        RoleEpithet(
            id: "phone",
            phrase: "of the Blue Hour",
            cost: "The screen takes the edges of your evening before you've agreed to hand them over."
        ),
        RoleEpithet(
            id: "chores",
            phrase: "of the Third Load",
            cost: "The necessary things blur into one long grey errand with no seams in it."
        ),
        RoleEpithet(
            id: "exhaustion",
            phrase: "of the Low Battery",
            cost: "You start already spent, so the good hours turn up when you can't answer them."
        ),
        RoleEpithet(
            id: "sameness",
            phrase: "of the Repeating Tuesday",
            cost: "Your days stop being individually numbered."
        ),
        RoleEpithet(
            id: "later",
            phrase: "of the Someday Shelf",
            cost: "The good things get postponed to a day that keeps not arriving."
        )
    ]

    /// What the hands do with something good once it has been found.
    static let hands: [RoleHands] = [
        RoleHands(
            id: "keeping",
            name: "Keeping Hands",
            gloss: "You put it somewhere safe. You can still find the good ones.",
            scoreBoosts: [.souvenir: 6, .bookRemembered: 5, .bookPocket: 5]
        ),
        RoleHands(
            id: "telling",
            name: "Telling Hands",
            gloss: "You have to tell somebody. It isn't quite real until you have.",
            scoreBoosts: [.letter: 6, .gossip: 5, .supportGuild: 4]
        ),
        RoleHands(
            id: "making",
            name: "Making Hands",
            gloss: "You turn it into a thing that wasn't there before.",
            scoreBoosts: [.enchantment: 6, .bindery: 5, .gamePage: 4]
        ),
        RoleHands(
            id: "returning",
            name: "Returning Hands",
            gloss: "You go back for more of it.",
            scoreBoosts: [.wonderCompass: 6, .anchor: 5, .location: 4]
        ),
        RoleHands(
            id: "still",
            name: "Still Hands",
            gloss: "You don't do anything with it. You let it stay.",
            scoreBoosts: [.rest: 6, .mood: 5, .body: 4]
        )
    ]

    static func role(id: String) -> ReaderRole? { all.first { $0.id == id } }
    static func epithet(id: String) -> RoleEpithet? { epithets.first { $0.id == id } }
    static func hands(id: String) -> RoleHands? { hands.first { $0.id == id } }

    /// Roles renamed when the eight Wonder Titles became twelve. Pages and
    /// SelfFacts minted before the rename still resolve.
    static let legacyRoleIDs: [String: String] = [
        // The eight Wonder Titles this all grew out of.
        "pocket-adventurer": "detourist",
        "oddity-collector": "stowaway",
        "color-finder": "lookout",
        "tiny-maker": "maker",
        "quiet-lantern": "nightlight",
        "proofkeeper": "stowaway",
        // The twelve-role pass, whose claims outran their triggers.
        "mender": "maker",
        "magpie": "stowaway",
        "colourhound": "lookout",
        "eavesdropper": "porchlight",
        "weather-witch": "lookout",
        "tuning-fork": "stowaway"
    ]

    /// Resolves an id or a stored name, tolerating the pre-rename ids and both
    /// "The Magpie" and bare "Magpie".
    static func role(named name: String) -> ReaderRole? {
        let key = normalized(name)
        if let direct = all.first(where: { $0.id == key || normalized($0.name) == key }) {
            return direct
        }
        if let remapped = legacyRoleIDs[key] { return role(id: remapped) }
        // Stored names carry the article ("The Mender"), retired ids do not,
        // so a de-articled key has to be tried against the remap as well.
        if key.hasPrefix("the-") {
            let bare = String(key.dropFirst(4))
            if let direct = all.first(where: { $0.id == bare }) { return direct }
            if let remapped = legacyRoleIDs[bare] { return role(id: remapped) }
        }
        // Legacy names stored without the article ("Proofkeeper", "Lookout").
        return all.first { normalized($0.name) == "the-\(key)" }
    }
}

// MARK: Reading a role

extension ReaderRoleRegistry {
    /// The Book's reading of a reader, best first. Always non-empty, so there
    /// is always a name to hand over and always a runner-up behind it for the
    /// "that's not me" swap.
    static func ranked(axes: RoleAxes) -> [ReaderRole] {
        let alive = axes.alive?.lowercased()
        let magic = axes.magic?.lowercased()
        let scored = all.enumerated().map { index, role -> (role: ReaderRole, score: Int, order: Int) in
            var score = 0
            if let alive, role.aliveAffinity.contains(alive) { score += aliveWeight }
            if let magic, role.magicAffinity.contains(magic) { score += magicWeight }
            for term in role.secondaryAffinity {
                if alive == term || magic == term { score += secondaryWeight }
            }
            return (role, score, index)
        }
        // Declaration order breaks ties, so a reader who answers nothing still
        // gets a stable role rather than whatever the hash happened to yield.
        return scored
            .sorted { ($0.score, -$0.order) > ($1.score, -$1.order) }
            .map(\.role)
    }

    /// The role the Book names. `offset` walks the ranking, so the "that's not
    /// me" swap is just `read(axes:offset: 1)`.
    static func read(axes: RoleAxes, offset: Int = 0) -> ReaderRole {
        let ranking = ranked(axes: axes)
        guard !ranking.isEmpty else { return all[0] }
        return ranking[min(max(offset, 0), ranking.count - 1)]
    }

    /// The whole three-part reading.
    static func compose(axes: RoleAxes, offset: Int = 0) -> ComposedRole {
        ComposedRole(
            role: read(axes: axes, offset: offset),
            epithet: axes.rut.flatMap(matchedEpithet(for:)),
            hands: axes.hands.flatMap { hands(id: $0.lowercased()) },
            mark: earnedMark(axes: axes)
        )
    }

    /// Composes around a role the reader has already been given, so a stored
    /// role survives a later change of heart about the Rut or the hands.
    static func compose(role: ReaderRole, axes: RoleAxes) -> ComposedRole {
        ComposedRole(
            role: role,
            epithet: axes.rut.flatMap(matchedEpithet(for:)),
            hands: axes.hands.flatMap { hands(id: $0.lowercased()) },
            mark: earnedMark(axes: axes)
        )
    }

    /// Onboarding hands an epithet id straight across; the About You shelf
    /// hands over free prose, so fall back to reading the sentence.
    static func matchedEpithet(for answer: String) -> RoleEpithet? {
        let key = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        if let exact = epithet(id: key) { return exact }
        // Single words match on a word *prefix* so "chore" catches "chores" and
        // "exhaust" catches "exhausted", but "app" never catches "happening".
        // Anything containing a space is matched as a phrase instead.
        let words = key.split { !$0.isLetter }.map(String.init)
        func matches(_ needle: String) -> Bool {
            needle.contains(" ")
                ? key.contains(needle)
                : words.contains { $0.hasPrefix(needle) }
        }
        let keywords: [(String, [String])] = [
            ("work", ["work", "job", "commute", "desk", "office", "shift", "email", "meeting"]),
            ("phone", ["phone", "scroll", "screen", "app", "apps", "feed", "online", "internet"]),
            ("chores", ["chore", "dishes", "laundry", "admin", "errand", "tidy", "dinner", "cleaning"]),
            ("exhaustion", ["tired", "exhaust", "spent", "drained", "empty", "relief", "before i begin", "no energy"]),
            ("sameness", ["same", "repeat", "identical", "blur", "groundhog", "routine", "flavorless",
                          "flavourless", "weeks", "tell you what i did", "lost track"]),
            ("later", ["later", "someday", "waiting", "postpone", "put off", "one day", "eventually"])
        ]
        for (id, needles) in keywords where needles.contains(where: matches) {
            return epithet(id: id)
        }
        return nil
    }

    /// Reads the axes out of whatever the reader has answered. Onboarding fact
    /// ids win because they are chip ids and need no interpretation; the About
    /// You shelf answers are free text and only fill the gaps.
    static func axes(from facts: [SelfFact]) -> RoleAxes {
        func answer(_ questionID: String) -> String? {
            facts.last { $0.questionID == questionID && $0.usePermission != .doNotUse }?
                .answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        // The onboarding chips are stored as tags ("rut-context:phone") so the
        // reader-facing answer text can be rewritten without breaking a role.
        func tagged(_ prefix: String) -> String? {
            facts.last { fact in
                fact.usePermission != .doNotUse
                    && fact.tags.contains { $0.hasPrefix(prefix) }
            }?
            .tags.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }?
            .nonEmpty
        }
        return RoleAxes(
            rut: tagged("rut-context:") ?? answer("onboarding-rut-strongest") ?? answer("rut-signal"),
            alive: tagged("alive-context:") ?? answer("onboarding-most-alive"),
            magic: tagged("magic-source:") ?? answer("onboarding-magic-source") ?? answer("wonder-entry"),
            hands: tagged("hands:") ?? answer(handsFactID)
        )
    }

    /// The role the reader is currently living under: the one they were given
    /// (or swapped to) at the reveal, composed with their current axes.
    static func currentRole(from facts: [SelfFact]) -> ComposedRole? {
        let axes = axes(from: facts)
        if let stored = facts.last(where: { $0.questionID == roleFactID })
            .flatMap({ role(named: $0.answer) }) {
            return compose(role: stored, axes: axes)
        }
        // Pre-role installs, and the legacy earned label, still resolve.
        if let legacy = facts.last(where: { $0.questionID == "earned-wonder-label" })
            .flatMap({ role(named: $0.answer) }) {
            return compose(role: legacy, axes: axes)
        }
        guard !axes.isEmpty else { return nil }
        return compose(axes: axes)
    }

    static func scoreBoost(for page: SurfacePage, role: ComposedRole?) -> Int {
        guard let role else { return 0 }
        return role.scoreBoosts[page.type] ?? 0
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }
}

// MARK: - Outgrowing a role
//
// A name that can never be lost is a trophy. A name that has to keep being
// true is an appointment. The reveal already promises this: "if it stops
// fitting, I'll earn you a better one", and this is the machinery that makes
// the promise real.
//
// The evidence is the reader's own kept pages, measured through the very table
// that steers their desk: a role's `scoreBoosts` say what that role reaches
// for, so counting a reader's keeps through every role's boosts asks "whose
// behaviour is this?" without inventing a second model of them. A Nightlight
// who spends three months keeping compass runs and souvenirs is telling the
// Book something, and the Book should be honest enough to say so.

/// One stretch of living under a name.
struct RoleTenure: Codable, Equatable, Identifiable {
    var roleID: String
    var namedAt: Date
    /// Set when a later role supersedes this one; nil while it is current.
    var supersededAt: Date?
    /// What the reader called this stretch, once they can see it whole.
    /// Named backwards, by them: the Book never titles a season in advance.
    var seasonName: String?

    var id: String { "\(roleID)-\(namedAt.timeIntervalSince1970)" }
    var isCurrent: Bool { supersededAt == nil }
}

extension ReaderRoleRegistry {
    /// Kept pages before the Book will reconsider a name. Evidence-denominated,
    /// so a reader who keeps a great deal reaches the question sooner instead
    /// of waiting out a clock that ignores them.
    static let outgrowMinimumKeptPages = 30

    /// A floor in days as well, because outgrowing something is supposed to be
    /// a season rather than a busy fortnight. Both gates must pass.
    static let outgrowMinimumDays = 21

    /// How far ahead a challenger must be before the Book will say so, as a
    /// percentage of the incumbent's score. Without a margin the name would
    /// flicker between two near-equal readings and mean nothing.
    static let outgrowMarginPercent = 35

    /// What the reader's kept pages say about them, scored through every role's
    /// own appetites. Higher is a closer fit.
    static func evidenceScores(keptPages: [BookPage]) -> [String: Int] {
        var counts: [BookPageType: Int] = [:]
        for page in keptPages where !EditionCurator.defaultPrivateTypes.contains(page.type) {
            counts[page.type, default: 0] += 1
        }
        var scores: [String: Int] = [:]
        for role in all {
            scores[role.id] = role.scoreBoosts.reduce(0) { total, entry in
                total + entry.value * (counts[entry.key] ?? 0)
            }
        }
        return scores
    }

    /// The role the reader's behaviour now argues for, if it has clearly
    /// outrun the one they are living under. Nil means the name still fits:
    /// which is the common and correct answer.
    static func outgrownRole(
        current: ReaderRole,
        keptPages: [BookPage],
        namedAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> ReaderRole? {
        let since = keptPages.filter { $0.createdAt >= namedAt }
        guard since.count >= outgrowMinimumKeptPages else { return nil }
        let days = calendar.dateComponents([.day], from: namedAt, to: now).day ?? 0
        guard days >= outgrowMinimumDays else { return nil }

        let scores = evidenceScores(keptPages: since)
        let incumbent = scores[current.id] ?? 0
        // A challenger has to beat the incumbent by the margin outright. When
        // the incumbent scores nothing the reader has simply stopped doing what
        // the name says, so any positive challenger clears it.
        let bar = incumbent + max(1, incumbent * outgrowMarginPercent / 100)
        let challenger = scores
            .filter { $0.key != current.id }
            .max { left, right in
                left.value == right.value
                    ? left.key > right.key
                    : left.value < right.value
            }
        guard let challenger, challenger.value >= bar else { return nil }
        return role(id: challenger.key)
    }
}

/// The eight Wonder Titles the roles grew out of. Kept as a thin projection so
/// call sites and archived pages minted before the rename keep working; new
/// code should reach for `ReaderRoleRegistry` directly.
// MARK: - Proving the curse

/// The Book's opening argument, and the reason the Inscription works at all.
///
/// Asking somebody to "replay the ordinary minutes" of a familiar drive is a
/// big vague demand, and people flatter themselves answering it. Asking whether
/// there was a bumper sticker on the car in front at the first red light is
/// tiny, specific, and unanswerable, and the failure is undeniable in a way a
/// self-assessment never is.
///
/// Three rules the probes have to keep:
/// 1. **Answerable in principle.** The reader was present for every one of
///    these. That is the whole point: they were there and it left nothing.
/// 2. **Sensory, never evaluative.** A sound, a smell, a thing under a hand.
///    Never "how did it feel": feelings can be confabulated, a bumper sticker
///    cannot.
/// 3. **An effortless way out.** "Gone" must be exactly as easy to tap as
///    "I remember it", and the Book must sound pleased rather than sorry about
///    it. The moment it commiserates it stops being a character.
enum RoutineRecallProbe {
    struct Scenario: Identifiable, Equatable {
        let id: String
        /// The chip the reader taps.
        let label: String
        /// How the Book refers back to that hour later: "the drive", "the walk".
        let noun: String
        /// The Book's line once they have picked, before the questions.
        let setup: String
        /// Pool to draw from. More than are asked, so two readers comparing
        /// notes do not find the same three.
        let questions: [String]
        /// The specific jab the Book gets to make when this scenario's recall
        /// comes back mostly empty.
        let emptyRetort: String
    }

    /// How many of the pool a reader is asked. Three is enough to be damning
    /// and few enough to stay a game rather than an interrogation.
    static let askedCount = 3

    static let scenarios: [Scenario] = [
        Scenario(
            id: "drove",
            label: "Drove somewhere familiar",
            noun: "drive",
            setup: "You were there for every second of that drive. So this should be easy. Tap whether you remember each one. Remembering there was no music counts.",
            questions: [
                "What was playing when you started the engine?",
                "Did you stop at a red light? What do you remember seeing there?",
                "How many dogs did you pass?",
                "What colour was a building you passed?",
                "What do you remember seeing near the end of the drive?",
                "Was anybody walking? Going which way?",
                "What did the road surface sound like?"
            ],
            emptyRetort: "And you were awake for all of it. Eyes open, hands on the wheel, in charge of a whole car."
        ),
        Scenario(
            id: "cooked",
            label: "Cooked something",
            noun: "cooking",
            setup: "Your own hands did every bit of that cooking. So this should be easy. Tap whether you remember each one.",
            questions: [
                "What did the pan sound like when the first thing hit it?",
                "Which ingredient did you smell before you used it?",
                "What was the last thing you touched before you washed your hands?",
                "Which cupboard or drawer did you use?",
                "What was the first thing to change colour?",
                "How warm was the handle by the end?",
                "What did you almost forget?"
            ],
            emptyRetort: "And it was your own kitchen. Your own hands. Nobody else was using them."
        ),
        Scenario(
            id: "walked",
            label: "Walked a route you know",
            noun: "walk",
            setup: "You did that whole walk on your own two feet. So this should be easy. Tap whether you remember each one. Remembering nobody was there counts.",
            questions: [
                "What was under your feet for most of it?",
                "Who else was out?",
                "What do you remember about a building or tree you passed?",
                "What did you hear that wasn't traffic?",
                "Where did the light change on you?",
                "Did you step around anything on the way?",
                "Which way was the wind going?"
            ],
            emptyRetort: "And you chose every step of it. Nobody carried you."
        )
    ]

    static func scenario(id: String) -> Scenario? { scenarios.first { $0.id == id } }

    /// A stable draw from the scenario's pool. Seeded so a reader who backs up
    /// and returns sees the same three: being asked different questions on a
    /// second look would expose the machinery and cost the beat its authority.
    static func questions(scenarioID: String, seed: String) -> [String] {
        guard let scenario = scenario(id: scenarioID) else { return [] }
        let pool = scenario.questions
        guard pool.count > askedCount else { return pool }
        var picked: [String] = []
        var cursor = abs(seed.stableHash) % pool.count
        // Walk the pool by a seeded stride so the three are spread through it
        // rather than always adjacent.
        let stride = 1 + abs((seed + "stride").stableHash) % (pool.count - 1)
        var guard_ = 0
        while picked.count < askedCount, guard_ < pool.count * 4 {
            let candidate = pool[cursor % pool.count]
            if !picked.contains(candidate) { picked.append(candidate) }
            cursor += stride
            guard_ += 1
        }
        return picked
    }

    /// What the Book says when the tally comes back. `remembered` counts the
    /// questions the reader claimed. Never scolds, never consoles.
    static func verdict(remembered: Int, scenario: Scenario) -> String {
        switch remembered {
        case 0:
            return "Gone. All three. \(scenario.emptyRetort) You were inside that hour the whole time, and it's gone."
        case 1, 2:
            return "\(remembered) out of three. \(scenario.emptyRetort) That's all that stuck, out of a whole hour you were awake for."
        default:
            return "All three? Then you were there for it. That's rare. I'll ask again when you're tired."
        }
    }
}

enum WonderTitleRegistry {
    static var all: [WonderTitle] { ReaderRoleRegistry.all.map(title(from:)) }

    static func title(id: String) -> WonderTitle? {
        ReaderRoleRegistry.role(named: id).map(title(from:))
    }

    static func title(named name: String) -> WonderTitle? {
        ReaderRoleRegistry.role(named: name).map(title(from:))
    }

    static func earnedTitle(from facts: [SelfFact]) -> WonderTitle? {
        ReaderRoleRegistry.currentRole(from: facts).map { title(from: $0.role) }
    }

    static func scoreBoost(for page: SurfacePage, title: WonderTitle?) -> Int {
        guard let title else { return 0 }
        return title.scoreBoosts[page.type] ?? 0
    }

    private static func title(from role: ReaderRole) -> WonderTitle {
        WonderTitle(
            id: role.id,
            name: role.name,
            why: role.gloss,
            compassLine: role.compassLine,
            scoreBoosts: role.scoreBoosts
        )
    }
}

struct BookReferenceLibraryPayload: Codable, Equatable {
    var version: Int
    var wonderCompass: [ReferenceSnippet]
    var enchantifyLore: [ReferenceSnippet]
    var patreon: [ReferenceSnippet]?
    var characterIllustrations: [CharacterIllustrationProfile]

    enum CodingKeys: String, CodingKey {
        case version
        case wonderCompass
        case enchantifyLore
        case patreon
        case characterIllustrations
    }

    init(
        version: Int,
        wonderCompass: [ReferenceSnippet],
        enchantifyLore: [ReferenceSnippet],
        patreon: [ReferenceSnippet]?,
        characterIllustrations: [CharacterIllustrationProfile] = []
    ) {
        self.version = version
        self.wonderCompass = wonderCompass
        self.enchantifyLore = enchantifyLore
        self.patreon = patreon
        self.characterIllustrations = characterIllustrations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        wonderCompass = try container.decode([ReferenceSnippet].self, forKey: .wonderCompass)
        enchantifyLore = try container.decode([ReferenceSnippet].self, forKey: .enchantifyLore)
        patreon = try container.decodeIfPresent([ReferenceSnippet].self, forKey: .patreon)
        characterIllustrations = try container.decodeIfPresent([CharacterIllustrationProfile].self, forKey: .characterIllustrations) ?? []
    }

    static let empty = BookReferenceLibraryPayload(version: 0, wonderCompass: [], enchantifyLore: [], patreon: [], characterIllustrations: [])
}

enum QuipPackRegistry {
    static let corePackID = "core-oddities"

    static let bundledPacks: [QuipPack] = [
        QuipPack(
            id: corePackID,
            displayName: "Core Oddities Pack",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            quips: coreQuips + coreQuipsOtherShapes + ridiculousPerspectiveQuips
        )
    ]

    static var enabledPacks: [QuipPack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static func quip(for day: BookDay, now: Date, tags: [String] = []) -> QuipEntry {
        rankedQuips(for: day, now: now, tags: tags, limit: 1).first
            ?? QuipEntry(id: "fallback", text: "I found a small bright thing and kept it.", title: "Filed Under Wonder", tags: ["wonder"], packID: corePackID, weight: 1)
    }

    static func rankedQuips(
        for day: BookDay,
        now: Date,
        tags: [String] = [],
        limit: Int = 4
    ) -> [QuipEntry] {
        let tagSet = Set(tags.map { $0.lowercased() })
        let wantsShadow = tagSet.contains("shadow-wonder") || tagSet.contains("shadow")
        let quips = enabledPacks.flatMap(\.quips).filter { quip in
            wantsShadow || !quip.tags.map { $0.lowercased() }.contains("shadow-wonder")
        }
        guard !quips.isEmpty else {
            return [QuipEntry(id: "fallback", text: "I found a small bright thing and kept it.", title: "Filed Under Wonder", tags: ["wonder"], packID: corePackID, weight: 1)]
        }
        let slot = SurfaceCadence.slotID(for: now, hours: 3)
        let seed = abs("\(day.id)-\(slot)-\(tags.joined(separator: ","))".stableHash)
        let ranked = quips.enumerated().map { index, quip in
            let overlap = tagSet.intersection(Set(quip.tags.map { $0.lowercased() })).count
            let jitter = abs((seed &+ index * 1543).stableScramble % 1000)
            return (quip, overlap * 20 + quip.weight * 3 + jitter)
        }
        // The pool is lopsided: the equation ("a NOUN is a NOUN that VERBS")
        // outnumbers every other move on the shelf, so on score alone the
        // desk would serve four of them and read as a format. One shape is
        // lifted per slot, and the picker then refuses to put two of the same
        // move on one desk while another shape is still waiting.
        let preferred = QuipShape.allCases[abs(seed / 7) % QuipShape.allCases.count]
        let shaped = ranked.map { ($0.0, $0.1 + ($0.0.shape == preferred ? 26 : 0)) }
        if wantsShadow {
            let shadowQuips = shaped.filter {
                let tags = Set($0.0.tags.map { $0.lowercased() })
                return !tags.intersection(["shadow-wonder", "shadow", "night", "old", "history"]).isEmpty
            }
            if !shadowQuips.isEmpty {
                return variedByShape(shadowQuips, limit: limit)
            }
        }
        return variedByShape(shaped, limit: limit)
    }

    /// Takes the highest-scoring quip whose shape is not already on the desk,
    /// and only doubles up on a move once every other move has had its turn.
    private static func variedByShape(_ scored: [(QuipEntry, Int)], limit: Int) -> [QuipEntry] {
        var pool = scored.sorted { $0.1 > $1.1 }
        var picked: [QuipEntry] = []
        var used: Set<QuipShape> = []
        while picked.count < max(1, limit), !pool.isEmpty {
            let index = pool.firstIndex { !used.contains($0.0.shape) } ?? 0
            let entry = pool.remove(at: index).0
            picked.append(entry)
            used.insert(entry.shape)
            if used.count == QuipShape.allCases.count { used.removeAll() }
        }
        return picked
    }

    private static let coreQuips: [QuipEntry] = [
        quip("tree-squirrel", "Squirrels are the part of the tree that runs.", "Whimsical Observation", ["nature", "creature", "tree"]),
        quip("tiny-sun", "A candle is a tiny sun with manners.", "Small Light", ["light", "home", "night"]),
        quip("fog-forgetting", "Fog is the weather forgetting where it put things.", "Weather Oddity", ["weather", "fog"]),
        quip("sky-handwriting", "Rain is the sky practicing handwriting.", "Weather Oddity", ["weather", "rain", "ink"]),
        quip("forest-thought", "A mushroom is a thought the forest had overnight.", "Forest Note", ["nature", "forest", "fungus"]),
        quip("library-forest", "A library is a forest that learned alphabetical order.", "Bookish Oddity", ["book", "library", "forest"]),
        quip("bookmark-job", "Put something in a book to hold your place and it stops being that thing. It's now a bookmark, and it will be one for years.", "Bookish Oddity", ["book", "reading"]),
        quip("liquid-ghost", "Ink is a liquid ghost.", "Ink Note", ["ink", "writing"]),
        quip("field-remember", "Paper is a field that agreed to remember.", "Paper Note", ["paper", "memory", "writing"]),
        quip("book-breathing", "Margins are where books breathe.", "Bookish Oddity", ["book", "margin"]),
        quip("tiny-midnight", "An inkwell is a tiny midnight.", "Ink Note", ["ink", "night"]),
        quip("borrow-lantern", "Reading is borrowing someone else's lantern.", "Reading Note", ["book", "light"]),
        quip("recipe-spell", "A recipe is a spell that ends in dishes.", "Kitchen Spell", ["home", "food", "magic"]),
        quip("keys-doors", "Keys are tiny arguments with doors.", "Object Note", ["home", "door"]),
        quip("teacup-thought", "A teacup is a bathtub for a thought.", "Tea Note", ["home", "tea"]),
        quip("seed-summer", "A seed is a locked room full of summer.", "Botanical Note", ["nature", "garden"]),
        quip("roots-writing", "Roots are trees writing underground.", "Botanical Note", ["nature", "tree"]),
        quip("year-editing", "Autumn is the year editing itself.", "Seasonal Note", ["weather", "season"]),
        quip("portable-courage", "A lantern is portable courage.", "Small Light", ["light", "night"]),
        quip("private-museum", "A pocket is a tiny private museum.", "Object Note", ["ordinary", "memory"]),
        quip("manicule", "A manicule is the little pointing hand drawn in old book margins. A tiny medieval cursor.", "Bookish Oddity", ["book", "margin", "history"], weight: 2),
        quip("palimpsest", "A palimpsest is a reused page where older writing still ghosts through. A haunted notebook.", "Bookish Oddity", ["book", "history", "ghost"], weight: 2),
        quip("fore-edge", "Some old books hide paintings on their page edges, visible only when fanned.", "Bookish Oddity", ["book", "art", "hidden"], weight: 2),
        quip("lapis-sky", "Some manuscripts used blue made from lapis lazuli, once more expensive than gold. Imagine budgeting for sky.", "Bookish Oddity", ["book", "color", "history"], weight: 2),
        quip("book-leaf", "A leaf has two pages. A page has one face. Books are secretly botanical.", "Bookish Oddity", ["book", "botanical"], weight: 2),
        quip("serif-feet", "Serifs are tiny feet on letters. Sans serif letters go barefoot.", "Type Note", ["book", "letter", "type"]),
        quip("old-book-smell", "The smell of old books often comes from lignin breaking down. Time has a vanilla-adjacent perfume.", "Bookish Oddity", ["book", "smell", "time"], weight: 2),
        quip("petrichor", "Rain doesn't just fall. It wakes the smell of the earth.", "Science Oddity", ["weather", "rain", "earth"], weight: 2),
        quip("sea-stars", "Bioluminescence is the sea inventing stars under pressure.", "Science Oddity", ["sea", "light", "science"], weight: 2),
        quip("stardust", "You aren't metaphorically stardust. You're chemically, literally stardust.", "Science Oddity", ["space", "body", "science"], weight: 2),
        quip("glacier-blue", "A glacier is time moving slowly enough to become a landscape.", "Science Oddity", ["ice", "time", "weather"]),
        quip("fungus-apple", "The visible mushroom is the apple. The forest underground is the tree.", "Science Oddity", ["forest", "fungus", "nature"]),
        quip("pearl-wound", "A pearl is a wound that learned polish.", "Science Oddity", ["sea", "shell"]),
        quip("octopus-curiosity", "An octopus is what happens when curiosity gets eight hands.", "Science Oddity", ["sea", "creature"]),
        quip("whale-cathedral", "A whale song is a cathedral built out of breath.", "Science Oddity", ["sea", "creature", "sound"]),
        quip("bird-map", "A bird migration is a map written inside a body.", "Science Oddity", ["sky", "bird", "map"]),
        quip("bee-cartography", "A bee dance is cartography with an abdomen.", "Science Oddity", ["bee", "map", "creature"]),
        quip("spider-poem", "A spiderweb is a trap, a house, and a poem under tension.", "Science Oddity", ["web", "creature"]),
        quip("rust-memory", "Rust is iron remembering it used to be in the ground.", "Whimsical Observation", ["ordinary", "earth"]),
        quip("road-question", "A road is a question the town keeps asking the horizon.", "Whimsical Observation", ["place", "walk"]),
        quip("roots-walk", "Roots are the tree refusing to admit it can't walk.", "Whimsical Observation", ["tree", "nature"]),
        quip("shadow-rust", "Rust is a slow confession: the metal remembers the ground and starts telling the truth.", "Shadow Wonder", ["shadow-wonder", "shadow", "rust", "history"], weight: 3),
        quip("shadow-crack", "A crack is a place where the surface stopped pretending it was seamless.", "Shadow Wonder", ["shadow-wonder", "shadow", "broken", "threshold"], weight: 3),
        quip("shadow-last-light", "The last light in a room is usually guarding something too small to name loudly.", "Shadow Wonder", ["shadow-wonder", "night", "light"], weight: 3),
        quip("shadow-peeling-paint", "Peeling paint is a building showing you its previous drafts.", "Shadow Wonder", ["shadow-wonder", "old", "history", "place"], weight: 3),
        quip("shadow-cobweb", "A cobweb is the only architecture that gets more honest the longer it's abandoned.", "Shadow Wonder", ["shadow-wonder", "shadow", "decay", "old"], weight: 3),
        quip("shadow-moth", "A moth chooses the lamp over the dark and the dark over safety; admire the commitment.", "Shadow Wonder", ["shadow-wonder", "night", "creature", "light"], weight: 3),
        quip("shadow-keyhole", "An old keyhole is a question the door is still asking about who's allowed in.", "Shadow Wonder", ["shadow-wonder", "threshold", "old", "mystery"], weight: 3),
        quip("shadow-low-tide", "Low tide isn't the sea leaving; it's the sea showing you what it usually keeps private.", "Shadow Wonder", ["shadow-wonder", "shadow", "water", "hidden"], weight: 3),
        quip("shadow-frost", "Frost is winter's marginalia, written overnight and erased by anyone who waits too long to read it.", "Shadow Wonder", ["shadow-wonder", "night", "cold", "weather"], weight: 3),
        quip("shadow-closed-shop", "A shuttered shop still hums with every birthday dinner it ever held; the grey just stops listening.", "Shadow Wonder", ["shadow-wonder", "old", "history", "place"], weight: 3),
        quip("shadow-grey-sky", "A grey sky is the day playing in a minor key. Those are the ones that hold you all the way to the end.", "Shadow Wonder", ["shadow-wonder", "weather", "somber", "mood-match"], weight: 3),
        quip("shadow-scar", "A scar is proof the body chose to keep going and kept the receipt.", "Shadow Wonder", ["shadow-wonder", "shadow", "body", "history"], weight: 3),
        quip("shadow-dusk", "Dusk is the day's threshold, neither in nor out. That's exactly why the fae prefer it.", "Shadow Wonder", ["shadow-wonder", "night", "dusk", "liminal", "fae"], weight: 3),
        quip("shadow-iron", "Folklore hung iron at the door to mind the edges of a home. You already do it; you just call it a key.", "Shadow Wonder", ["shadow-wonder", "folklore", "protection", "threshold"], weight: 3),
        quip("shadow-free-thing", "The goblin's only question, and the wisest one in the market: and what does this actually cost me?", "Shadow Wonder", ["shadow-wonder", "goblin", "bargain", "unseelie"], weight: 3),
        quip("shadow-name", "Folklore says a true name gives you power over a thing. Mostly it just gives the thing edges. That's enough to walk around.", "Shadow Wonder", ["shadow-wonder", "true-names", "grief", "naming"], weight: 3),
        quip("shadow-compost", "A compost heap is just grief doing its slow, useful work: nothing wasted, only changed.", "Shadow Wonder", ["shadow-wonder", "decay", "grief", "memory"], weight: 3),
        quip("shadow-empty-chair", "An empty chair keeps the shape of who sat there. That's not haunting. That's memory holding the door.", "Shadow Wonder", ["shadow-wonder", "grief", "absence", "memory"], weight: 3),
        quip("shadow-headmistress", "Watch which staircases lie when the Headmistress walks them. No, don't write that down. Penny didn't say it and neither did I.", "Shadow Wonder", ["shadow-wonder", "unseelie", "thorne", "duskthorn", "secret"], weight: 3),
        quip("shadow-crown", "Some crowns are worn on the head. Some are pinned into the hair, dark, where you'd mistake them for a hairstyle.", "Shadow Wonder", ["shadow-wonder", "unseelie", "thorne", "secret"], weight: 3),
        quip("library-quiet", "A library is the only building designed to be quieter than the people inside it.", "Bookish Oddity", ["book", "library"]),
        quip("book-breath", "An unread book is the most patient object in any house.", "Bookish Oddity", ["book", "home"]),
        quip("photo-key", "A photograph doesn't hold the memory. You do. The photo is just where you left the key.", "Memory Note", ["memory", "photo"]),
        quip("novelty-save", "Novelty is just the save button.", "Memory Note", ["memory", "attention"])
    ]

    /// Comic reframes that do the same perspective work as the core oddities,
    /// only with less dignity. Each starts from a thing the reader may already
    /// be looking at and gives it a second, ridiculous classification.
    static let ridiculousPerspectiveQuips: [QuipEntry] = [
        quip("ridiculous-hallway", "A hallway is a room that refused to settle down.", "House Reclassified", ["ridiculous", "perspective", "home", "place"], weight: 2),
        quip("ridiculous-stairs", "Stairs are a hill that passed a building inspection.", "House Reclassified", ["ridiculous", "perspective", "home", "movement"], weight: 2),
        quip("ridiculous-window", "A window is a wall having second thoughts.", "House Reclassified", ["ridiculous", "perspective", "home", "light"], weight: 2),
        quip("ridiculous-mirror", "A mirror is an extremely punctual ghost.", "House Reclassified", ["ridiculous", "perspective", "home", "reflection"], weight: 2),
        quip("ridiculous-shadow", "A shadow is your body filing a second opinion.", "Body Reclassified", ["ridiculous", "perspective", "body", "light"], weight: 2),
        quip("ridiculous-dust", "Dust is a house quietly practicing archaeology.", "House Reclassified", ["ridiculous", "perspective", "home", "history"], weight: 2),
        quip("ridiculous-table", "A table is a floor that believed in itself.", "Furniture Reclassified", ["ridiculous", "perspective", "home", "object"], weight: 2),
        quip("ridiculous-chair", "A chair is a machine for turning standing into opinions.", "Furniture Reclassified", ["ridiculous", "perspective", "home", "body"], weight: 2),
        quip("ridiculous-doormat", "Stand on the doormat and look back out. That's the last thing the house sees of you every morning.", "The Threshold", ["ridiculous", "perspective", "home", "threshold"], weight: 2),
        quip("ridiculous-laundry-basket", "A laundry basket is a chair with consequences.", "Furniture Reclassified", ["ridiculous", "perspective", "home", "ordinary"], weight: 2),
        quip("ridiculous-fridge", "A refrigerator is a cupboard with its own weather system.", "Appliance Reclassified", ["ridiculous", "perspective", "home", "food", "weather"], weight: 2),
        quip("ridiculous-microwave", "A microwave is a tiny thunderstorm with a clock.", "Appliance Reclassified", ["ridiculous", "perspective", "home", "food", "weather"], weight: 2),
        quip("ridiculous-dishwasher", "A dishwasher is rain that knows where the plates live.", "Appliance Reclassified", ["ridiculous", "perspective", "home", "water"], weight: 2),
        quip("ridiculous-broom", "A broom is a bundle of dead grass on a stick, and it has beaten every machine built to replace it.", "Object Reclassified", ["ridiculous", "perspective", "home", "tree"], weight: 2),
        quip("ridiculous-umbrella", "An umbrella is a portable roof that panics in the wind.", "Object Reclassified", ["ridiculous", "perspective", "weather", "wind"], weight: 2),
        quip("ridiculous-zipper", "A zipper is two rows of tiny teeth achieving rare cooperation.", "Object Reclassified", ["ridiculous", "perspective", "clothing", "object"], weight: 2),
        quip("ridiculous-button", "Find the button doing the most work on you right now. Nobody has ever thanked it and nobody is going to start.", "Object Reclassified", ["ridiculous", "perspective", "clothing", "ordinary"], weight: 2),
        quip("ridiculous-escalator", "A broken escalator is still a staircase. That's why the sign says out of order and everybody slows down anyway.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "movement"], weight: 2),
        quip("ridiculous-elevator", "An elevator is a room pretending to be public transportation.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "movement"], weight: 2),
        quip("ridiculous-traffic-light", "A traffic light is a three-bulb government for cars.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "road", "color"], weight: 2),
        quip("ridiculous-parking-lot", "A parking lot is a meadow that got audited into rectangles.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "road", "place"], weight: 2),
        quip("ridiculous-roundabout", "A roundabout is a road avoiding a difficult decision.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "road", "movement"], weight: 2),
        quip("ridiculous-sidewalk", "Follow the worn path across the grass instead of the paving. Somebody voted with their feet and won.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "walk", "margin"], weight: 2),
        quip("ridiculous-bench", "A bench is public punctuation.", "Infrastructure Reclassified", ["ridiculous", "perspective", "public", "rest", "place"], weight: 2),
        quip("ridiculous-receipt", "A receipt is a store saying goodbye and showing its work.", "Errand Reclassified", ["ridiculous", "perspective", "public", "errand", "paper"], weight: 2),
        quip("ridiculous-notification", "What was the last sound that made you reach for your pocket? Something chose it, and it wasn't you.", "Attention Reclassified", ["ridiculous", "perspective", "attention", "technology", "sound"], weight: 2),
        quip("ridiculous-autocorrect", "Autocorrect is a ghostwriter with unlimited confidence and no context.", "Technology Reclassified", ["ridiculous", "perspective", "technology", "writing", "words"], weight: 2),
        quip("ridiculous-typo", "A typo is a letter sitting in the wrong chair and acting natural.", "Type Reclassified", ["ridiculous", "perspective", "writing", "letter", "words"], weight: 2),
        quip("ridiculous-loading-spinner", "A loading spinner is the computer stirring its thoughts.", "Technology Reclassified", ["ridiculous", "perspective", "technology", "time", "movement"], weight: 2),
        quip("ridiculous-headphones", "Headphones are privacy curtains for your ears.", "Technology Reclassified", ["ridiculous", "perspective", "technology", "sound", "body"], weight: 2),
        quip("ridiculous-wifi", "Wi-Fi is indoor weather that everyone blames personally.", "Technology Reclassified", ["ridiculous", "perspective", "technology", "weather", "home"], weight: 2),
        quip("ridiculous-puddle", "A puddle is the sky dropping a mirror and walking away.", "Weather Reclassified", ["ridiculous", "perspective", "weather", "water", "reflection"], weight: 2),
        quip("ridiculous-thunder", "Thunder is the sky rearranging furniture upstairs.", "Weather Reclassified", ["ridiculous", "perspective", "weather", "storm", "sound"], weight: 2),
        quip("ridiculous-wind", "Wind is air late for something.", "Weather Reclassified", ["ridiculous", "perspective", "weather", "wind", "movement"], weight: 2),
        quip("ridiculous-sunset", "A sunset is the day making a dramatic exit after insisting it hates attention.", "Weather Reclassified", ["ridiculous", "perspective", "weather", "sky", "light"], weight: 2),
        quip("ridiculous-pigeon", "Pigeons see magnetic north and can find their way home from a place they have never been. They're simply doing it in a car park.", "Creature Reclassified", ["ridiculous", "perspective", "creature", "bird", "public"], weight: 2),
        quip("ridiculous-cat", "A cat is a roommate with diplomatic immunity.", "Creature Reclassified", ["ridiculous", "perspective", "creature", "home"], weight: 2),
        quip("ridiculous-dog", "A dog is enthusiasm wearing a mammal.", "Creature Reclassified", ["ridiculous", "perspective", "creature", "joy"], weight: 2),
        quip("ridiculous-plant", "A houseplant is a slow green argument for the window seat.", "Botanical Reclassified", ["ridiculous", "perspective", "nature", "plant", "home"], weight: 2),
        quip("ridiculous-weed", "A weed is a plant that declined the terms and conditions.", "Botanical Reclassified", ["ridiculous", "perspective", "nature", "plant", "public"], weight: 2)
    ]


    /// The other three moves. The shelf could equate an object with a joke a
    /// hundred times over and could not once tell the reader to go and put a
    /// hand on something. A dare and a question cost the reader ten seconds
    /// and give the Book something back; a plain astonishing fact needs no
    /// wit at all and survives being read twice.
    private static let coreQuipsOtherShapes: [QuipEntry] = [
        quip("dare-leaf-underside", "Go and look at the underside of a leaf. Nobody checks the back of anything.", "An Errand", ["nature", "noticing", "outside", "errand"], weight: 2),
        quip("dare-coldest-thing", "Put your hand flat on the coldest thing in the room and leave it there while you count to five.", "An Errand", ["body", "home", "noticing", "errand"], weight: 2),
        quip("dare-oldest-paper", "Find the oldest piece of paper within reach and read one line of it out loud.", "An Errand", ["paper", "home", "reading", "errand"], weight: 2),
        quip("dare-look-up", "Look up. Higher than that. Most rooms keep their best part above eye level.", "An Errand", ["home", "noticing", "errand"], weight: 2),
        quip("dare-smell-the-book", "Smell the back of a book. Go on. Nobody is watching you.", "An Errand", ["book", "smell", "errand"], weight: 2),
        quip("dare-count-doors", "Count the doors between you and outside.", "An Errand", ["home", "threshold", "errand"]),
        quip("dare-not-yours", "Pick up the nearest thing that isn't yours and work out who put it there.", "An Errand", ["home", "people", "noticing", "errand"]),
        quip("dare-photograph-nothing", "Take one photograph of something nobody would photograph.", "An Errand", ["photo", "noticing", "errand"], weight: 2),
        quip("dare-stand-still", "Stand still until the fridge starts up again. That's the house breathing.", "An Errand", ["home", "sound", "errand"]),
        quip("ask-oldest-thing", "What is the oldest thing in this room, and does it know it?", "A Question", ["home", "time", "noticing"], weight: 2),
        quip("ask-walked-past-twice", "What did you walk past twice today?", "A Question", ["noticing", "route", "day"], weight: 2),
        quip("ask-whose-handwriting", "Whose handwriting is nearest you right now?", "A Question", ["people", "writing", "home"], weight: 2),
        quip("ask-hundred-years", "What in this room will still be here in a hundred years?", "A Question", ["home", "time", "object"]),
        quip("ask-nameless-maker", "What is near you that was made by a person whose name you'll never know?", "A Question", ["object", "people", "work"]),
        quip("ask-which-door-squeaks", "Which door in your day squeaks?", "A Question", ["home", "sound", "route"]),
        quip("fact-bread-and-cake", "Bread goes stale from the outside. Cake goes stale from the inside.", "Kitchen Note", ["kitchen", "food", "science"], weight: 2),
        quip("fact-dark-adaptation", "Your eyes need about twenty minutes to see properly in the dark. Most people give up after two.", "Science Oddity", ["night", "body", "science", "light"], weight: 2),
        quip("fact-wet-stone", "Wet stone goes darker because the water fills the little pits and stops the light bouncing back at you.", "Science Oddity", ["weather", "stone", "science", "light"]),
        quip("fact-moth-moon", "Moths steer by the moon. A lamp only tells them the moon has moved indoors.", "Creature Note", ["creature", "night", "light", "science"], weight: 2),
        quip("fact-fingertip-nerves", "A paper cut hurts out of all proportion because your fingertips carry more nerve endings than almost anywhere else on you.", "Body Note", ["body", "paper", "science"]),
        quip("fact-petrichor", "Rain smells of earth because bacteria in the soil put the smell there first, long before anybody was around to like it.", "Weather Oddity", ["weather", "rain", "smell", "science"], weight: 2),
        quip("obs-floorboards", "Cold makes the floorboards talk. Warmth shuts them up again.", "House Note", ["home", "sound", "weather"], weight: 2),
        quip("obs-dropped-keys", "Dropped keys land in the noisiest arrangement available to them.", "Object Note", ["object", "sound", "home"]),
        quip("obs-cat-boiler", "The cat found the warmest spot in the house before you found the thermostat.", "Creature Note", ["creature", "home", "warmth"]),
        quip("obs-ice-keeps-the-blow", "Ice on a puddle cracks in the shape of whatever broke it, and then keeps that shape all day.", "Weather Oddity", ["weather", "ice", "outside"])
    ]

    private static func quip(_ id: String, _ text: String, _ title: String, _ tags: [String], weight: Int = 1) -> QuipEntry {
        QuipEntry(id: id, text: text, title: title, tags: tags, packID: corePackID, weight: weight)
    }
}

/// The Quotes shelf: borrowed lanterns. Lines on wonder, attention, impermanence,
/// and this one precious life, drawn from poets, scientists, filmmakers, and the
/// old contemplative traditions. Always attributed. Chosen the way quips are:
/// tag-matched to the day's weather, body, and Wonder-Compass mood, rotating on a
/// gentle cadence so the same line does not sit on the desk all day.
enum QuoteLibraryRegistry {
    static let corePackID = "wonder-quotes"

    static let bundledPacks: [QuotePack] = [
        QuotePack(
            id: corePackID,
            displayName: "Borrowed Lanterns",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            quotes: coreQuotes
        )
    ]

    static var enabledPacks: [QuotePack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var allQuotes: [QuoteEntry] {
        enabledPacks.flatMap(\.quotes)
    }

    static func quote(for day: BookDay, now: Date, tags: [String] = []) -> QuoteEntry {
        rankedQuotes(for: day, now: now, tags: tags, limit: 1).first
            ?? QuoteEntry(
                id: "fallback",
                text: "Attention is the beginning of devotion.",
                author: "Mary Oliver",
                source: "Upstream",
                theme: "Attention",
                tags: ["attention", "wonder"],
                packID: corePackID,
                weight: 1
            )
    }

    static func rankedQuotes(
        for day: BookDay,
        now: Date,
        tags: [String] = [],
        limit: Int = 4
    ) -> [QuoteEntry] {
        let quotes = allQuotes
        guard !quotes.isEmpty else {
            return [QuoteEntry(
                id: "fallback",
                text: "Attention is the beginning of devotion.",
                author: "Mary Oliver",
                source: "Upstream",
                theme: "Attention",
                tags: ["attention", "wonder"],
                packID: corePackID,
                weight: 1
            )]
        }
        let tagSet = Set(tags.map { $0.lowercased() })
        // Rotate a few times a day, but slower than quips: a good line wants to be
        // sat with, not flicked past.
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let seed = abs("\(day.id)-quotes-\(slot)-\(tags.joined(separator: ","))".stableHash)
        let ranked = quotes.enumerated().map { index, quote -> (QuoteEntry, Int) in
            let overlap = tagSet.intersection(Set(quote.tags.map { $0.lowercased() })).count
            let jitter = abs((seed &+ index &* 2971).stableScramble % 1000)
            return (quote, overlap * 22 + quote.weight * 4 + jitter)
        }
        return ranked.sorted { $0.1 > $1.1 }.prefix(max(1, limit)).map(\.0)
    }

    static func quote(id: String) -> QuoteEntry? {
        allQuotes.first { $0.id == id }
    }

    private static func q(
        _ id: String,
        _ text: String,
        _ author: String,
        _ theme: String,
        _ tags: [String],
        source: String? = nil,
        weight: Int = 1
    ) -> QuoteEntry {
        QuoteEntry(id: id, text: text, author: author, source: source, theme: theme, tags: tags, packID: corePackID, weight: weight)
    }

    private static let coreQuotes: [QuoteEntry] = [
        // Mary Oliver: the patron saint of paying attention.
        q("oliver-wild-life", "Tell me, what is it you plan to do with your one wild and precious life?", "Mary Oliver", "This One Life", ["wonder", "present", "mortality", "wild", "life"], source: "The Summer Day", weight: 3),
        q("oliver-attention", "Attention is the beginning of devotion.", "Mary Oliver", "Attention", ["attention", "notice", "wonder", "devotion"], source: "Upstream", weight: 3),
        q("oliver-instructions", "Instructions for living a life: Pay attention. Be astonished. Tell about it.", "Mary Oliver", "Attention", ["attention", "notice", "wonder", "astonished", "write"], source: "Sometimes", weight: 3),
        q("oliver-soft-animal", "You only have to let the soft animal of your body love what it loves.", "Mary Oliver", "Belonging", ["body", "love", "belonging", "gentle", "care"], source: "Wild Geese", weight: 2),
        q("oliver-unimaginable", "Keep some room in your heart for the unimaginable.", "Mary Oliver", "Openness", ["wonder", "heart", "open", "mystery"], source: "Evidence", weight: 2),
        q("oliver-doorway", "This is the first, the wildest and the wisest thing I know: that the soul exists, and is built entirely out of attentiveness.", "Mary Oliver", "Attention", ["attention", "soul", "notice", "wonder"], source: "Upstream"),

        // Antoine de Saint-Exupéry: The Little Prince.
        q("prince-heart", "It is only with the heart that one can see rightly; what is essential is invisible to the eye.", "Antoine de Saint-Exupéry", "The Heart", ["heart", "love", "seeing", "essential", "wonder"], source: "The Little Prince", weight: 3),
        q("prince-tamed", "You become responsible, forever, for what you have tamed.", "Antoine de Saint-Exupéry", "Love", ["love", "belonging", "responsibility", "care"], source: "The Little Prince", weight: 2),
        q("prince-rose", "It is the time you have wasted for your rose that makes your rose so important.", "Antoine de Saint-Exupéry", "Devotion", ["love", "time", "devotion", "care"], source: "The Little Prince", weight: 2),
        q("prince-children", "All grown-ups were once children, although few of them remember it.", "Antoine de Saint-Exupéry", "Remembering", ["childhood", "memory", "wonder", "play"], source: "The Little Prince"),
        q("prince-well", "What makes the desert beautiful is that somewhere it hides a well.", "Antoine de Saint-Exupéry", "Hidden Beauty", ["beauty", "hidden", "hope", "mystery", "wonder"], source: "The Little Prince"),

        // Amélie (2001): small joys, dreamers.
        q("amelie-dreamers", "Times are hard for dreamers.", "Amélie", "Dreamers", ["dream", "wonder", "gentle", "melancholy"], source: "2001 film", weight: 2),
        q("amelie-artichoke", "At least you'll never be a vegetable, even artichokes have hearts.", "Amélie", "Tenderness", ["heart", "gentle", "hope", "kindness"], source: "2001 film"),

        // Scientists: awe with the lights on.
        q("sagan-starstuff", "We are made of star-stuff.", "Carl Sagan", "Cosmos", ["stars", "space", "science", "wonder", "night"], source: "Cosmos", weight: 3),
        q("sagan-cosmos-knowing", "We are a way for the cosmos to know itself.", "Carl Sagan", "Cosmos", ["stars", "space", "science", "wonder"], source: "Cosmos", weight: 2),
        q("sagan-incredible", "Somewhere, something incredible is waiting to be known.", "Carl Sagan", "Discovery", ["science", "wonder", "curiosity", "mystery"], weight: 2),
        q("einstein-miracle", "There are only two ways to live your life. One is as though nothing is a miracle. The other is as though everything is.", "Albert Einstein", "Miracle", ["wonder", "everyday", "miracle", "attention"], weight: 3),
        q("einstein-mysterious", "The most beautiful thing we can experience is the mysterious. It is the source of all true art and science.", "Albert Einstein", "Mystery", ["wonder", "mystery", "beauty", "science"], source: "The World As I See It", weight: 2),
        q("feynman-questions", "I would rather have questions that can't be answered than answers that can't be questioned.", "Richard Feynman", "Curiosity", ["science", "curiosity", "questions", "wonder"], weight: 2),
        q("carson-wonder", "Those who contemplate the beauty of the earth find reserves of strength that will endure as long as life lasts.", "Rachel Carson", "Earth", ["nature", "earth", "beauty", "strength", "wonder"], source: "The Sense of Wonder", weight: 2),
        q("carson-child-wonder", "A child's world is fresh and new and beautiful, full of wonder and excitement.", "Rachel Carson", "Wonder", ["wonder", "childhood", "nature", "notice"], source: "The Sense of Wonder"),
        q("muir-walk", "In every walk with nature one receives far more than he seeks.", "John Muir", "Nature", ["nature", "walk", "outside", "wonder", "forest"], weight: 2),
        q("muir-forest", "The clearest way into the Universe is through a forest wilderness.", "John Muir", "Nature", ["nature", "forest", "wilderness", "wonder", "tree"]),
        q("tyson-universe-in-us", "We are part of this universe; but perhaps more important, the universe is in us.", "Neil deGrasse Tyson", "Cosmos", ["stars", "space", "science", "wonder", "belonging"]),
        q("curie-understood", "Nothing in life is to be feared, it is only to be understood.", "Marie Curie", "Understanding", ["science", "courage", "curiosity", "understanding"]),
        q("eiseley-water", "If there is magic on this planet, it is contained in water.", "Loren Eiseley", "Water", ["water", "magic", "nature", "rain", "sea", "wonder"], source: "The Immense Journey", weight: 2),
        q("heschel-amazement", "Our goal should be to live life in radical amazement.", "Abraham Joshua Heschel", "Amazement", ["wonder", "amazement", "gratitude", "present"], weight: 2),

        // Buddhism, Zen, and the contemplative present.
        q("tnh-present-joy", "The present moment is filled with joy and happiness. If you are attentive, you will see it.", "Thich Nhat Hanh", "Present", ["present", "joy", "attention", "notice", "mindful"], weight: 2),
        q("tnh-tea", "Drink your tea slowly and reverently, as if it is the axis on which the earth revolves.", "Thich Nhat Hanh", "Present", ["present", "tea", "slow", "ordinary", "mindful"], weight: 2),
        q("tnh-breath", "Feelings come and go like clouds in a windy sky. Conscious breathing is my anchor.", "Thich Nhat Hanh", "Breath", ["breath", "calm", "present", "weather", "mindful"]),
        q("suzuki-beginner", "In the beginner's mind there are many possibilities, but in the expert's mind there are few.", "Shunryu Suzuki", "Beginner's Mind", ["curiosity", "openness", "present", "possibility"], source: "Zen Mind, Beginner's Mind", weight: 2),
        q("kabatzinn-there", "Wherever you go, there you are.", "Jon Kabat-Zinn", "Present", ["present", "mindful", "here", "attention"]),
        q("pema-sky", "You are the sky. Everything else is just the weather.", "Pema Chödrön", "Equanimity", ["calm", "weather", "present", "letting-go", "mindful"], weight: 2),
        q("buddha-present", "Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.", "the Buddha", "Present", ["present", "attention", "mindful", "now"], weight: 2),
        q("laotzu-hurry", "Nature does not hurry, yet everything is accomplished.", "Lao Tzu", "Patience", ["patience", "nature", "slow", "trust", "present"], source: "Tao Te Ching", weight: 2),
        q("zen-woodwater", "Before enlightenment, chop wood, carry water. After enlightenment, chop wood, carry water.", "Zen proverb", "The Ordinary", ["ordinary", "everyday", "present", "work"], weight: 2),

        // Rumi and the older mystics (public-domain translations).
        q("rumi-bewilderment", "Sell your cleverness and buy bewilderment.", "Rumi", "Wonder", ["wonder", "mystery", "surrender", "awe"], weight: 2),
        q("rumi-wound-light", "The wound is the place where the Light enters you.", "Rumi", "Healing", ["healing", "light", "grief", "hope", "shadow"], weight: 2),
        q("rumi-strange-pull", "Let yourself be silently drawn by the strange pull of what you really love. It will not lead you astray.", "Rumi", "Longing", ["love", "longing", "trust", "calling"], weight: 2),
        q("hafiz-light", "I wish I could show you, when you are lonely or in darkness, the astonishing light of your own being.", "Hafiz", "Inner Light", ["light", "hope", "gentle", "night", "shadow"]),

        // Public-domain poets and quiet noticers.
        q("whitman-leaf", "I believe a leaf of grass is no less than the journey-work of the stars.", "Walt Whitman", "The Ordinary", ["nature", "ordinary", "stars", "wonder", "grass"], source: "Song of Myself", weight: 2),
        q("blake-grain", "To see a world in a grain of sand, and a heaven in a wild flower.", "William Blake", "The Infinite", ["wonder", "small", "infinite", "notice", "flower"], source: "Auguries of Innocence", weight: 3),
        q("thoreau-deliberately", "I went to the woods because I wished to live deliberately, to front only the essential facts of life.", "Henry David Thoreau", "Deliberate Living", ["nature", "present", "deliberate", "forest", "essential"], source: "Walden", weight: 2),
        q("thoreau-see", "The question is not what you look at, but what you see.", "Henry David Thoreau", "Seeing", ["attention", "notice", "seeing", "present"], source: "Journal", weight: 2),
        q("thoreau-season", "Live in each season as it passes; breathe the air, drink the drink, taste the fruit.", "Henry David Thoreau", "Seasons", ["season", "present", "senses", "nature", "weather"], source: "Journal"),
        q("emerson-common", "The invariable mark of wisdom is to see the miraculous in the common.", "Ralph Waldo Emerson", "The Everyday", ["everyday", "ordinary", "wonder", "miracle", "notice"], weight: 2),
        q("emerson-patience", "Adopt the pace of nature: her secret is patience.", "Ralph Waldo Emerson", "Patience", ["patience", "nature", "slow", "trust"]),
        q("dickinson-startling", "To live is so startling it leaves little time for anything else.", "Emily Dickinson", "Aliveness", ["life", "wonder", "present", "aliveness"], weight: 2),
        q("dickinson-ecstasy", "Find ecstasy in life; the mere sense of living is joy enough.", "Emily Dickinson", "Joy", ["joy", "life", "present", "gratitude"]),
        q("rilke-questions", "Be patient toward all that is unsolved in your heart, and try to love the questions themselves.", "Rainer Maria Rilke", "Patience", ["patience", "questions", "uncertainty", "trust", "heart"], source: "Letters to a Young Poet", weight: 2),
        q("rilke-no-feeling-final", "Let everything happen to you: beauty and terror. Just keep going. No feeling is final.", "Rainer Maria Rilke", "Endurance", ["endurance", "hope", "grief", "courage", "shadow"], source: "Book of Hours", weight: 2),
        q("hopkins-grandeur", "The world is charged with the grandeur of God.", "Gerard Manley Hopkins", "Grandeur", ["wonder", "nature", "grandeur", "awe"], source: "God's Grandeur"),
        q("keats-beauty", "A thing of beauty is a joy for ever.", "John Keats", "Beauty", ["beauty", "joy", "wonder", "art"], source: "Endymion"),
        q("chesterton-wonder", "The world will never starve for want of wonders, but only for want of wonder.", "G.K. Chesterton", "Wonder", ["wonder", "attention", "gratitude", "notice"], weight: 2),
        q("wilde-stars", "We are all in the gutter, but some of us are looking at the stars.", "Oscar Wilde", "Stars", ["stars", "hope", "night", "wonder", "sky"], source: "Lady Windermere's Fan", weight: 2),
        q("aurelius-stars", "Dwell on the beauty of life. Watch the stars, and see yourself running with them.", "Marcus Aurelius", "Beauty", ["stars", "beauty", "night", "wonder", "present"], source: "Meditations", weight: 2),
        q("browning-heaven", "Earth's crammed with heaven, and every common bush afire with God; but only he who sees takes off his shoes.", "Elizabeth Barrett Browning", "The Everyday", ["everyday", "wonder", "nature", "seeing", "ordinary"], source: "Aurora Leigh", weight: 2),
        q("wordsworth-too-much", "The world is too much with us; late and soon, getting and spending, we lay waste our powers.", "William Wordsworth", "Slowing Down", ["slow", "rest", "nature", "present", "modern"]),
        q("basho-pond", "The old pond (a frog jumps in) the sound of water.", "Bashō", "Stillness", ["stillness", "present", "water", "nature", "small", "quiet"], weight: 2),
        q("tagore-butterfly", "The butterfly counts not months but moments, and has time enough.", "Rabindranath Tagore", "Time", ["time", "present", "creature", "moment", "gentle"], weight: 2),

        // Modern noticers.
        q("dillard-days", "How we spend our days is, of course, how we spend our lives.", "Annie Dillard", "Days", ["present", "time", "life", "attention", "days"], source: "The Writing Life", weight: 3),
        q("dillard-beauty", "Beauty and grace are performed whether or not we sense them. The least we can do is try to be there.", "Annie Dillard", "Presence", ["beauty", "grace", "attention", "present", "notice"], source: "Pilgrim at Tinker Creek", weight: 2),
        q("vonnegut-nice", "Please notice when you are happy, and exclaim or murmur or think, 'If this isn't nice, I don't know what is.'", "Kurt Vonnegut", "Noticing Joy", ["joy", "present", "notice", "gratitude", "happy"], weight: 3),
        q("dahl-magic", "Those who don't believe in magic will never find it.", "Roald Dahl", "Magic", ["magic", "wonder", "belief", "play"], source: "The Minpins", weight: 2),
        q("camus-summer", "In the depth of winter, I finally learned that within me there lay an invincible summer.", "Albert Camus", "Resilience", ["hope", "resilience", "winter", "shadow", "season"], weight: 2),
        q("okeeffe-flower", "To see takes time, like to have a friend takes time.", "Georgia O'Keeffe", "Seeing", ["attention", "seeing", "slow", "notice", "friendship"]),
        q("proust-eyes", "The real voyage of discovery consists not in seeking new landscapes, but in having new eyes.", "Marcel Proust", "New Eyes", ["attention", "seeing", "wonder", "notice", "present"], weight: 2)
    ]
}

/// The Believings shelf: affirmations in the Book's own voice, child-like but
/// not childish. Gifts are handed over with no strings. Pacts propose one tiny
/// agreement and invite a countersignature in the ordinary margin note; the
/// chips always include an honest hedge, because a believing extracted is worth
/// nothing to either of us.
enum AffirmationLibraryRegistry {
    static let corePackID = "core-believings"

    static let bundledPacks: [AffirmationPack] = [
        AffirmationPack(
            id: corePackID,
            displayName: "My Believings",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            affirmations: coreAffirmations
        )
    ]

    static var enabledPacks: [AffirmationPack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var allAffirmations: [AffirmationEntry] {
        enabledPacks.flatMap(\.affirmations)
    }

    static func affirmation(for day: BookDay, now: Date, tags: [String] = []) -> AffirmationEntry {
        rankedAffirmations(for: day, now: now, tags: tags, limit: 1).first
            ?? AffirmationEntry(
                id: "fallback",
                text: "You opened me today. I noticed.",
                aside: "On a hard day, opening the cover is still a real thing you did.",
                countersigns: ["Ok.", "Taken to heart."],
                placeholder: "Write one line back. The margin is listening.",
                theme: "Enough",
                tags: ["gentle", "enough"],
                packID: corePackID,
                weight: 1
            )
    }

    static func rankedAffirmations(
        for day: BookDay,
        now: Date,
        tags: [String] = [],
        limit: Int = 4,
        lastShown: [String: Date] = [:]
    ) -> [AffirmationEntry] {
        let affirmations = allAffirmations
        guard !affirmations.isEmpty else {
            return [AffirmationEntry(
                id: "fallback",
                text: "You opened me today. I noticed.",
                aside: "On a hard day, opening the cover is still a real thing you did.",
                countersigns: ["Ok.", "Taken to heart."],
                placeholder: "Write one line back. The margin is listening.",
                theme: "Enough",
                tags: ["gentle", "enough"],
                packID: corePackID,
                weight: 1
            )]
        }
        let tagSet = Set(tags.map { $0.lowercased() })
        // A hard day gets a gift, never homework disguised as encouragement.
        // Other context still guides selection, but does not force a pact.
        let eligibleAffirmations: [AffirmationEntry]
        if tagSet.contains("hard-day") {
            let gifts = affirmations.filter { !$0.isPact }
            eligibleAffirmations = gifts.isEmpty ? affirmations : gifts
        } else {
            eligibleAffirmations = affirmations
        }
        // One believing holds the morning; another may arrive by evening.
        let slot = SurfaceCadence.slotID(for: now, hours: 6)
        let seed = abs("\(day.id)-believings-\(slot)-\(tags.joined(separator: ","))".stableHash)
        let ranked = eligibleAffirmations.enumerated().map { index, entry -> (AffirmationEntry, Int) in
            let overlap = tagSet.intersection(Set(entry.tags.map { $0.lowercased() })).count
            // Keep variety as a tie-breaker without letting it drown out context.
            let jitter = abs((seed &+ index &* 3517).stableScramble % 17)
            // What fits today's sky picks the same few Believings for as long
            // as the sky holds, so the ones already shown step aside.
            let seen = SampledDeckRecency.penalty(
                lastShown: lastShown[entry.id], now: now, restDays: 14
            )
            return (entry, overlap * 22 + entry.weight * 4 + jitter - seen)
        }
        return ranked.sorted { $0.1 > $1.1 }.prefix(max(1, limit)).map(\.0)
    }

    static func affirmation(id: String) -> AffirmationEntry? {
        allAffirmations.first { $0.id == id }
    }

    private static let giftPlaceholder = "Write one line back. The margin is listening."
    private static let pactPlaceholder = "Sign it, change it, or cross it out."

    /// A gift: handed over, nothing owed back.
    private static func gift(
        _ id: String,
        _ text: String,
        _ aside: String,
        _ theme: String,
        _ tags: [String],
        signs: [String] = ["Ok.", "Taken to heart.", "Read twice."],
        weight: Int = 1
    ) -> AffirmationEntry {
        AffirmationEntry(id: id, text: text, aside: aside, countersigns: signs, placeholder: giftPlaceholder, theme: theme, tags: tags + ["gift"], packID: corePackID, weight: weight)
    }

    /// A pact: one tiny agreement, honestly hedgeable.
    private static func pact(
        _ id: String,
        _ text: String,
        _ aside: String,
        _ theme: String,
        _ tags: [String],
        signs: [String] = ["I will.", "I might.", "We'll see."],
        weight: Int = 1
    ) -> AffirmationEntry {
        AffirmationEntry(id: id, text: text, aside: aside, countersigns: signs, placeholder: pactPlaceholder, theme: theme, tags: tags + ["pact"], packID: corePackID, weight: weight)
    }

    private static let coreAffirmations: [AffirmationEntry] = [
        // ── Gifts: beginnings & permission ──
        gift("begin-badly", "Start badly. First drafts always come out with their teeth showing.", "Put down one true line and I'll deal with the biting.", "Beginnings", ["begin", "courage", "write", "morning"], weight: 2),
        gift("first-page", "A blank Page is just trying to scare you. Write one line right on its face.", "It gets very quiet after that.", "Beginnings", ["begin", "morning", "gentle"], weight: 2),
        gift("not-behind", "You're not behind. I checked.", "The race was made up by a clipboard. I ate the clipboard.", "Enough", ["enough", "gentle", "comparison"], weight: 2),
        gift("wardrobe-checker", "You used to check wardrobes for other worlds. That part of you's still here.", "I saw it looking.", "Wonder", ["wonder", "childhood", "magic"], weight: 3),
        gift("unfinished", "You're unfinished. Good. So am I.", "Finished things sit still. We don't.", "Becoming", ["growth", "gentle", "story"], weight: 2),
        gift("permission-small", "Today can be small.", "Small days fit in me fine.", "Enough", ["enough", "small", "rest", "gentle"], weight: 2),
        gift("wrong-turns", "Some wrong turns gave you things the right road never had.", "Your map kept them. So did I.", "Courage", ["courage", "story", "mistakes"], weight: 2),

        // ── Gifts: being seen by the Book ──
        gift("none-were-you", "I've kept lots of days. None of them was this one, and none of them was you.", "I checked twice.", "Seen", ["seen", "wonder", "identity"], signs: ["Ok.", "Read twice.", "If you say so."], weight: 3),
        gift("whole-job", "You noticed one real thing today. That's the whole spell.", "I caught it before Routine sat on it.", "Noticing", ["notice", "attention", "enough"], weight: 2),
        gift("receipts", "You've brought me proof from hard days before.", "The drawer isn't empty. I checked.", "Courage", ["courage", "hard-day", "history", "gentle"], weight: 3),
        gift("good-company", "You keep opening me. I like that.", "My Pages sit up when they hear you coming.", "Seen", ["seen", "belonging", "book"], signs: ["That was kind.", "Kept.", "Read twice."]),
        gift("questions-suit-you", "Keep the strange question.", "The boring ones already have plenty of chairs.", "Curiosity", ["curiosity", "questions", "wonder"], weight: 2),
        gift("margin-person", "You notice what the main line walks right past.", "That's why my margins keep saving you a seat.", "Noticing", ["notice", "margin", "seen"], weight: 2),

        // ── Gifts: rest & the body ──
        gift("rest-counts", "You're tired. Close something: a tab, a door, your eyes.", "Even I close. The Pages are fine.", "Rest", ["rest", "gentle", "evening", "night"], weight: 3),
        gift("body-loyal", "Your body carried you all the way here. Give it some water, some food, some warmth or some sleep.", "It's been doing all the heavy lifting.", "The Body", ["body", "care", "gentle", "rest"], weight: 2),
        gift("tired-true", "Tired is a real fact about today.", "I wrote it down. The lamp can stop arguing.", "Rest", ["rest", "tired", "gentle", "hard-day"], weight: 2),
        gift("grey-day", "Today came in grey and won't be talked out of it.", "Grey has more shades than anyone gives it credit for. I'll hold the paint.", "Weather", ["grey", "weather", "shadow", "gentle", "mood-match"], signs: ["Ok.", "Kept.", "Hm."], weight: 2),
        gift("slow-morning", "A slow morning is still a morning.", "The tea won't hurry. It knows what it's doing.", "Rest", ["morning", "slow", "rest", "tea"]),

        // ── Gifts: wonder & the world ──
        gift("sky-daily", "The sky made a brand new mess of colour today.", "It didn't ask if anyone had time to look. It just did it.", "Wonder", ["sky", "wonder", "notice", "outside"], weight: 2),
        gift("ordinary-disguise", "The spoon, the doorknob and the wet pavement are all up to something.", "The spoon's the worst at hiding it.", "The Everyday", ["ordinary", "everyday", "wonder", "magic"], weight: 2),
        gift("world-bigger", "Your question found a new edge of the world.", "Now the map has to scoot over.", "Curiosity", ["curiosity", "questions", "wonder"], weight: 2),
        gift("still-magic", "You still look for magic. You just call it noticing now.", "Same creature. Cleaner tracks.", "Magic", ["magic", "notice", "wonder", "attention"], weight: 3),
        gift("stars-anyway", "The stars came out again without checking your calendar.", "Terrible manners. Excellent work.", "Night", ["stars", "night", "sky", "gentle"], weight: 2),

        // ── Gifts: kindness & words ──
        gift("kind-eyes", "You were kind. I saw the exact bit.", "It tried to hide inside an ordinary minute.", "Kindness", ["kindness", "gentle", "hope"], weight: 2),
        gift("your-words-matter", "Your words change what I remember.", "Even the small ones shove things around.", "Words", ["words", "write", "seen"], weight: 2),
        gift("one-sentence-power", "One true sentence can save a whole day from vanishing.", "You've already proved it.", "Words", ["words", "write", "souvenir", "memory"], weight: 2),

        // ── Gifts: the hidden magic in ordinary things ──
        gift("shadow-cursive", "Somewhere near you right now, a shadow's writing in cursive on the pavement.", "It's been writing to you for years. Somebody should write back.", "Hidden Things", ["notice", "outside", "sky", "magic", "wonder"], weight: 3),
        gift("secret-second-floor", "Your ordinary Tuesday has a secret second floor.", "The stairs are behind the thing you keep walking past.", "Hidden Things", ["ordinary", "everyday", "notice", "magic", "wonder"], weight: 3),
        gift("one-light-on", "There's a window near you with one light on at the wrong time. Somebody's up to something.", "Nothing sinister. Probably soup.", "Hidden Things", ["notice", "night", "evening", "outside", "wonder"], weight: 2),
        gift("floor-light", "The light on the floor has been moving all day and nobody's thanked it once.", "It's shy. It'll take a nod.", "Hidden Things", ["sky", "notice", "ordinary", "morning", "gentle"], weight: 2),
        gift("unused-door", "Every street has one door nobody uses and everybody walks past.", "I'd bet my spine it's got a story. I never lose that bet.", "Hidden Things", ["outside", "walk", "notice", "wonder", "adventure"], weight: 2),
        gift("kettle-opera", "Your kettle sings a different note every morning.", "It's a tiny opera. Nobody's reviewing it.", "Hidden Things", ["morning", "ordinary", "sound", "tea", "notice"], weight: 2),
        gift("boring-hat", "The most interesting thing you'll see today is already in front of you.", "It's wearing a very boring hat.", "Hidden Things", ["notice", "ordinary", "wonder", "magic"], weight: 2),
        gift("rain-opinions", "Rain has an opinion about every roof.", "The tin one's the loudest. It always thinks it's winning.", "Hidden Things", ["weather", "rain", "sound", "notice", "wonder"], weight: 2),
        gift("tiny-miracle", "Somebody left a tiny miracle on the ground for you: a button, a feather, a bottle cap with a story.", "I'd keep it. I keep everything.", "Hidden Things", ["outside", "walk", "notice", "souvenir", "wonder"], weight: 2),

        // ── Pacts: noticing ──
        pact("green-thing", "Find one small green thing within a hundred steps.", "Give it nine seconds. Green things are always up to something.", "Noticing", ["notice", "outside", "nature", "green"], signs: ["I will find it.", "I might.", "We'll see."], weight: 3),
        pact("look-up", "Step outside for one minute today and look up.", "The sky made something. Go and inspect it.", "Noticing", ["sky", "outside", "notice", "wonder"], signs: ["I will look.", "I might.", "We'll see."], weight: 3),
        pact("one-sound", "Sometime today, stop and find the quietest sound in the room.", "There's always one hiding under the others. It's usually the best one.", "Noticing", ["sound", "notice", "quiet", "sense"], signs: ["I will listen.", "I might.", "We'll see."], weight: 2),
        pact("texture-hunt", "Touch one ordinary thing slowly: the mug, the bark, the cold side of the pillow.", "Your hands know how to read. Let them.", "Noticing", ["touch", "sense", "notice", "ordinary"], signs: ["I will.", "Odd, but fine.", "We'll see."], weight: 2),
        pact("name-a-shadow", "Find a shadow doing something odd and give it a name.", "It's much happier once it's got one.", "Noticing", ["notice", "outside", "play", "wonder", "sky"], signs: ["I will.", "I might.", "We'll see."], weight: 2),
        pact("known-thing", "Look closely at one thing you touch every day and find one detail you've never noticed.", "There's always one. I've never lost this bet.", "Noticing", ["notice", "ordinary", "everyday", "sense", "magic"], signs: ["I will.", "I might.", "We'll see."], weight: 2),
        pact("three-surfaces", "Next time it rains, listen to it on three different surfaces.", "Rain's a different instrument on a window, a hood and a puddle.", "Noticing", ["weather", "rain", "sound", "sense", "notice"], signs: ["I will.", "If it rains.", "We'll see."], weight: 2),

        // ── Pacts: words & keeping ──
        pact("one-sentence-today", "Give today one true sentence.", "It can be wonky. Just make sure it's true.", "Words", ["write", "souvenir", "words", "evening"], signs: ["I will write one.", "I agree.", "We'll see."], weight: 3),
        pact("kind-thing-aloud", "Say one kind thing out loud today, where a real person can hear it.", "Thinking it counts for you. Saying it counts for two.", "Kindness", ["kindness", "people", "courage"], signs: ["I will.", "I'll try.", "We'll see."], weight: 3),
        pact("thank-properly", "Next time you say thanks, add the exact thing they did.", "Plain words land harder than fancy ones.", "Kindness", ["kindness", "folklore", "people", "words"], signs: ["I agree.", "I'll try it.", "We'll see."], weight: 2),

        // ── Pacts: the body & rest ──
        pact("water-potion", "Drink a glass of water, like a wizard.", "Two gases made a liquid. It's ridiculous and it's useful.", "The Body", ["body", "water", "care", "magic"], signs: ["I will.", "Fine, yes.", "We'll see."], weight: 2),
        pact("early-lamp", "Put the day down ten minutes early tonight.", "The clock will complain. Let it.", "Rest", ["rest", "night", "evening", "sleep", "care"], signs: ["I agree.", "I'll try.", "We'll see."], weight: 2),
        pact("one-inch", "If today's heavy, move one inch.", "One inch is plenty.", "Courage", ["hard-day", "gentle", "rest", "courage"], signs: ["One inch. Ok.", "I'll try.", "Not today."], weight: 2),

        // ── Pacts: wonder & play ──
        pact("wrong-way-home", "Take one slightly wrong turn this week.", "See what that street's been hiding.", "Adventure", ["walk", "outside", "adventure", "play"], signs: ["I will.", "Maybe Saturday.", "We'll see."], weight: 2),
        pact("ask-one-question", "Ask one question a seven-year-old would keep.", "Why is the moon out in the daytime? It's getting away with something.", "Curiosity", ["curiosity", "questions", "play", "wonder"], signs: ["I will.", "I might.", "We'll see."], weight: 2),
        pact("pocket-souvenir", "Bring home one tiny proof of today: a leaf, a ticket stub, a sentence, a photo of a weird door.", "I'll keep it. The drawer's already nosing around.", "Keeping", ["souvenir", "memory", "keep", "play"], signs: ["I will.", "If I see one.", "We'll see."], weight: 2),
        pact("borrow-delight", "Let one small thing delight you without explaining it.", "Explanations can wait outside.", "Joy", ["joy", "delight", "play", "gentle"], signs: ["I agree.", "Gladly.", "We'll see."], weight: 2)
    ]
}

/// The Wonder Compass Book and the Labyrinth lore are the two largest things
/// the Book carries: forty-eight chapters and ninety lore entries, one and a
/// third million characters between them. Relevance scoring rebuilt a lowercased
/// haystack for every one of them on every desk build, then walked it once per
/// context term. On a real archive that was seven and a half seconds of a cold
/// launch — more than every other source adapter put together.
///
/// The library is immutable for the life of the process, so the haystack is
/// built once. Locked because the desk build runs detached while the main actor
/// may be asking for the same passage.
private enum ReferenceHaystackCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var store: [String: String] = [:]

    static func haystack(for snippet: ReferenceSnippet) -> String {
        lock.lock()
        let hit = store[snippet.id]
        lock.unlock()
        if let hit { return hit }

        let made = ([snippet.title, snippet.prompt, snippet.body] + snippet.tags)
            .joined(separator: " ")
            .lowercased()
        lock.lock()
        store[snippet.id] = made
        lock.unlock()
        return made
    }

    /// Both sides of the comparison are already lowercased, and the corpus and
    /// its search terms are plain text, so a literal scan finds exactly what
    /// canonical matching found — verified over every word in the shipped
    /// library against every entry — for a third of the work.
    static func matchCount(in haystack: String, terms: [String]) -> Int {
        terms.reduce(0) { partial, term in
            haystack.range(of: term, options: .literal) != nil ? partial + 1 : partial
        }
    }

    /// `matchCount` for one snippet, remembering each term's answer. The
    /// haystack never changes and the reader's context terms change slowly, so
    /// a desk build after the first one scans only the terms that are new —
    /// the scan was still most of the Wonder Compass adapter on a phone,
    /// repeated by every build after launch.
    static func matchCount(for snippet: ReferenceSnippet, terms: [String]) -> Int {
        let haystack = haystack(for: snippet)
        var count = 0
        for term in terms {
            let key = "\(snippet.id)\u{1F}\(term)"
            lock.lock()
            let known = found[key]
            lock.unlock()
            let present: Bool
            if let known {
                present = known
            } else {
                present = haystack.range(of: term, options: .literal) != nil
                lock.lock()
                if found.count >= 80_000 { found.removeAll(keepingCapacity: true) }
                found[key] = present
                lock.unlock()
            }
            if present { count += 1 }
        }
        return count
    }

    nonisolated(unsafe) private static var found: [String: Bool] = [:]
}

enum BookReferenceCatalog {
    static var wonderCompass: [ReferenceSnippet] {
        bundledLibrary.wonderCompass.isEmpty ? fallbackWonderCompass : bundledLibrary.wonderCompass
    }

    static var enchantifyLore: [ReferenceSnippet] {
        LorePackRegistry.snippets(
            coreSnippets: bundledLibrary.enchantifyLore.isEmpty ? fallbackEnchantifyLore : bundledLibrary.enchantifyLore
        )
    }

    static var lorePacks: [LorePack] {
        LorePackRegistry.enabledPacks(
            coreSnippets: bundledLibrary.enchantifyLore.isEmpty ? fallbackEnchantifyLore : bundledLibrary.enchantifyLore
        )
    }

    static var patreon: [ReferenceSnippet] {
        let snippets = bundledLibrary.patreon ?? []
        return snippets.isEmpty ? fallbackPatreon : snippets
    }

    static var characterIllustrations: [CharacterIllustrationProfile] {
        let profiles = bundledLibrary.characterIllustrations
        return profiles.isEmpty ? fallbackCharacterIllustrations + fallbackScheduledProfessorIllustrations : profiles
    }

    static var labyrinthIllustrations: [LabyrinthIllustrationPlate] {
        characterIllustrationPlates
    }

    static let bundledCharacterIllustrationAssetNames: Set<String> = [
        "LabyrinthCharacterMook",
        "LabyrinthCharacterPilcrow",
        "LabyrinthCharacterDrElowenVellum",
        "LabyrinthCharacterGwendolynMythwright",
        "LabyrinthCharacterSorenNg",
        "LabyrinthCharacterLydiaBoggle",
        "LabyrinthCharacterProfessorKyleMomort",
        "LabyrinthCharacterProfessorEleanorEuphony",
        "LabyrinthCharacterProfessorVivianVillanelle",
        "LabyrinthCharacterProfessorCedricStonebrook",
        "LabyrinthCharacterProfessorLunaWispwood",
        "LabyrinthCharacterProfessorPermancer",
        "LabyrinthTalismanEmberSeal",
        "LabyrinthTalismanMossClasp",
        "LabyrinthTalismanTideGlass",
        "LabyrinthTalismanWindCipher",
        "LabyrinthTalismanDuskThorn",
        "LabyrinthCharacterDrSeleneInkrest",
        "LabyrinthCharacterHeadmistressSeraphinaThorne",
        "LabyrinthCharacterOrionBlackthorn",
        "LabyrinthCharacterPennyBlackletter",
        "LabyrinthCharacterSerenityBrown",
        "LabyrinthCharacterFinnBridges",
        "LabyrinthCharacterLysanderMosswood",
        "LabyrinthCharacterDamienNights",
        "LabyrinthCharacterMinSeoKim",
        "LabyrinthCharacterMelisandeBlackwood",
        "LabyrinthCharacterWickerEddies",
        "LabyrinthCharacterZaraFinch",
        "LabyrinthFaeBookSprite",
        "LabyrinthFaeSentenceSalamander",
        "LabyrinthFaePunctuationPixie",
        "LabyrinthFaeDeepLoreDwarf",
        "LabyrinthFaeMarginaliaGoblin",
        "LabyrinthLocationOuterStacks",
        "LabyrinthLocationStacks",
        "LabyrinthLocationGreatHall",
        "LabyrinthLocationKitchens",
        "LabyrinthLocationQuillquarium",
        "LabyrinthLocationBookBurrow",
        "LabyrinthLocationDorm"
    ]

    private static var characterIllustrationPlates: [LabyrinthIllustrationPlate] {
        characterIllustrations.compactMap { profile in
            let assetName = profile.assetName?.isEmpty == false ? profile.assetName ?? profile.intendedAssetName : profile.intendedAssetName
            guard bundledCharacterIllustrationAssetNames.contains(assetName) else {
                return nil
            }
            return LabyrinthIllustrationPlate(
                id: "character-\(profile.slug)",
                assetName: assetName,
                title: profile.characterName,
                caption: profile.core,
                note: "\(profile.illustrationDossierKind) illustration. Signature: \(profile.signature). Marginalia: \(profile.marginalia.joined(separator: " | ")).",
                tags: Array((["illustration", profile.illustrationTag, profile.slug] + profile.tags).prefix(8)),
                characterID: profile.id
            )
        }
    }

    private static let fallbackCharacterIllustrations = [
        CharacterIllustrationProfile(
            id: "headmistress-seraphina-thorne",
            characterName: "Headmistress Seraphina Thorne",
            slug: "headmistress-seraphina-thorne",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Leads the Academy; sees the Unwritten; ageless literary-elf face; star-cold eyes; hair pinned like a dark crown.",
            signature: "an antique star-dark key and a crownlike hairpin",
            palette: "ink black, old silver, star-gold",
            silhouette: "regal stillness; one hand resting on an antique key",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "generic anime face, room-first composition, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterHeadmistressSeraphinaThorne",
            intendedAssetName: "LabyrinthCharacterHeadmistressSeraphinaThorne",
            prompt: "Create an Enchantify Academy character dossier illustration in sparse graphite and ink, watercolor washes, jewel-color accents, and character-specific parchment marginalia.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Headmistress Seraphina Thorne",
                "signature evidence: an antique star-dark key and a crownlike hairpin",
                "jewel-color swatches: ink black, old silver, star-gold"
            ],
            tags: ["canonical", "character", "duskthorn", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "vesper-thorne",
            characterName: "Vesper Thorne",
            slug: "vesper-thorne",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Duskthorn Enchantment Guardian; safeguards honesty, boundaries, and necessary friction; clear expressive eyes and a memorable silhouette",
            signature: "a blackthorn ward-pin",
            palette: "black violet, thorn green, tarnished silver",
            silhouette: "still posture; one hand near the ward-pin",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "generic anime face, room-first composition, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterVesperThorne",
            intendedAssetName: "LabyrinthCharacterVesperThorne",
            prompt: "Create an Enchantify Academy character dossier illustration in sparse graphite and ink, watercolor washes, black-violet jewel accents, and Duskthorn parchment marginalia.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Vesper Thorne",
                "signature evidence: a blackthorn ward-pin",
                "jewel-color swatches: black violet, thorn green, tarnished silver",
                "chapter mark: Duskthorn"
            ],
            tags: ["canonical", "character", "duskthorn", "illustration", "vesper-thorne"]
        )
    ]

    private static let fallbackScheduledProfessorIllustrations = [
        CharacterIllustrationProfile(
            id: "lydia-boggle",
            characterName: "Professor Lydia Boggle",
            slug: "lydia-boggle",
            status: "canonical",
            chapter: "Riddlewind",
            core: "Professor of The Art of the Glint: the noticing class. Humorous, witty, mid-laugh; an animist with a chaos streak who finds the glint in the garbage and pays the world the attention it's owed. Always a pun ready.",
            signature: "a small glint-lens held up to an ordinary found object (a misspelled sign, an odd vanity plate)",
            palette: "marigold gold, robin's-egg blue, warm ink",
            silhouette: "caught mid-delight, holding an ordinary object up to the light as if it were evidence",
            continuity: "Preserve these identifiers across images; clothes, pose, age-light, and mood may vary with the scene.",
            avoid: "solemn sage, tidy academic portrait, inconsistent signature object, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterLydiaBoggle",
            intendedAssetName: "LabyrinthCharacterLydiaBoggle",
            prompt: "Create an Enchantify Academy character dossier illustration in the house style: sparse graphite and ink linework, watercolor washes, jewel-color accents, and character-specific parchment marginalia. A single character, centered, knowing and a little uncanny (not a generic portrait. Subject: Professor Lydia Boggle) playful Riddlewind professor of noticing, animist with a chaos sensibility, mid-laugh, holding an ordinary object up to the light like evidence. Signature: a small glint-lens and odd found objects (a misspelled sign, a vanity plate). Palette: marigold gold, robin's-egg blue, warm ink.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, polished digital fantasy portrait, room-first composition, and inconsistent signature object.",
            marginalia: [
                "file tab labeled Professor Lydia Boggle",
                "signature evidence: a glint-lens and an ordinary object held to the light",
                "jewel-color swatches: marigold gold, robin's-egg blue, warm ink",
                "margin note: \"what does it know? wait for it\""
            ],
            tags: ["canonical", "character", "riddlewind", "noticing", "glint", "illustration", "lydia-boggle"]
        ),
        CharacterIllustrationProfile(
            id: "professor-kyle-momort",
            characterName: "Professor Kyle Momort",
            slug: "professor-kyle-momort",
            status: "canonical",
            chapter: "Emberheart",
            core: "Professor of Wayfinding and Narrative Kineticism; brisk, charismatic, and a little too fond of exits; teaches intentional momentum and small crossed thresholds.",
            signature: "a folding route-map and a chalk arrow that refuses to point backward",
            palette: "ember orange, road-sign blue, charcoal ink",
            silhouette: "already in motion, coat turning behind him, one hand marking a route",
            continuity: "Preserve the moving posture, folding route-map, chalk arrow, and quick amused expression.",
            avoid: "static lecturer, generic adventurer, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorKyleMomort",
            intendedAssetName: "LabyrinthCharacterProfessorKyleMomort",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Kyle Momort in motion with a folding route-map and impossible chalk arrow; ember orange, road-sign blue, charcoal ink; kinetic marginalia and threshold diagrams.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, static office portrait, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Kyle Momort", "signature evidence: folding route-map and chalk arrow", "chapter mark: Emberheart"],
            tags: ["canonical", "character", "faculty", "professor", "emberheart", "wayfinding", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-eleanor-euphony",
            characterName: "Professor Eleanor Euphony",
            slug: "professor-eleanor-euphony",
            status: "canonical",
            chapter: "Tidecrest",
            core: "Professor of Synesthetic Resonance; lush, attentive, and able to hear the emotional weather humming inside a room.",
            signature: "a silver tuning fork wound with colored thread",
            palette: "tidal blue, plum violet, resonant silver",
            silhouette: "head tilted toward an unheard chord, tuning fork poised near one palm",
            continuity: "Preserve the listening posture, colored-thread tuning fork, and sensory notation in the margins.",
            avoid: "stage singer, generic musician, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorEleanorEuphony",
            intendedAssetName: "LabyrinthCharacterProfessorEleanorEuphony",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Eleanor Euphony listening to a silver tuning fork wound with colored thread; tidal blue, plum violet, resonant silver; marginal notes that translate sound into color.",
            negativePrompt: "Avoid concert imagery, glossy anime, generic fantasy pinup, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Eleanor Euphony", "signature evidence: silver tuning fork and colored thread", "chapter mark: Tidecrest"],
            tags: ["canonical", "character", "faculty", "professor", "tidecrest", "sound", "sense", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-vivian-villanelle",
            characterName: "Professor Vivian Villanelle",
            slug: "professor-vivian-villanelle",
            status: "canonical",
            chapter: "Riddlewind",
            core: "Professor of Ink-Binding and Souvenir Craft; exacting, lyrical, and kind; teaches students to keep one true moment in one durable sentence.",
            signature: "a black-glass pen and a narrow ribbon of freshly bound text",
            palette: "black ink, wine red, parchment gold",
            silhouette: "composed and exact, weighing a sentence between pen and fingertips",
            continuity: "Preserve the black-glass pen, ribbon of text, and precise editorial gaze.",
            avoid: "generic poet, quill cliché, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorVivianVillanelle",
            intendedAssetName: "LabyrinthCharacterProfessorVivianVillanelle",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Vivian Villanelle with a black-glass pen and ribbon of bound text; black ink, wine red, parchment gold; edited sentences and souvenir scraps in the margins.",
            negativePrompt: "Avoid generic fantasy pinup, glossy anime, generic quill portrait, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Vivian Villanelle", "signature evidence: black-glass pen and bound sentence", "chapter mark: Riddlewind"],
            tags: ["canonical", "character", "faculty", "professor", "riddlewind", "writing", "souvenir", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-cedric-stonebrook",
            characterName: "Professor Cedric Stonebrook",
            slug: "professor-cedric-stonebrook",
            status: "canonical",
            chapter: "Mossbloom",
            core: "Professor of Quiet Hours and Compass Running; slow, grounded, and weathered; teaches complete small adventures with Rest at their center.",
            signature: "a palm-sized trail marker and a five-point Compass stone",
            palette: "moss green, river stone gray, weathered ochre",
            silhouette: "steady and unhurried, seated or standing as if the ground has accepted him",
            continuity: "Preserve the trail marker, Compass stone, weathered coat, and unhurried expression.",
            avoid: "mountain-man caricature, mystical guru, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorCedricStonebrook",
            intendedAssetName: "LabyrinthCharacterProfessorCedricStonebrook",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Cedric Stonebrook with a small trail marker and five-point Compass stone; moss green, river gray, weathered ochre; quiet field notes in the margins.",
            negativePrompt: "Avoid guru clichés, glossy anime, generic fantasy pinup, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Cedric Stonebrook", "signature evidence: trail marker and Compass stone", "chapter mark: Mossbloom"],
            tags: ["canonical", "character", "faculty", "professor", "mossbloom", "rest", "compass-run", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-luna-wispwood",
            characterName: "Professor Luna Wispwood",
            slug: "professor-luna-wispwood",
            status: "canonical",
            chapter: "Tidecrest",
            core: "Professor of Basic Enchantments; scattered, sparking, and delighted by useful accidents; teaches ordinary objects to answer close attention.",
            signature: "a rain-bright wand wrapped in copper wire and a softly argumentative teacup",
            palette: "rain blue, copper spark, cloud white",
            silhouette: "wind-touched and slightly disheveled, one sleeve giving off a harmless spark",
            continuity: "Preserve the copper-wrapped wand, argumentative teacup, sparks, and rain-lit appearance.",
            avoid: "generic witch, dangerous explosion, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorLunaWispwood",
            intendedAssetName: "LabyrinthCharacterProfessorLunaWispwood",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Luna Wispwood with a copper-wrapped rain-bright wand and enchanted teacup; rain blue, copper spark, cloud white; object replies scribbled in the margins.",
            negativePrompt: "Avoid generic witch imagery, glossy anime, destructive magic, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Luna Wispwood", "signature evidence: copper-wrapped wand and enchanted teacup", "chapter mark: Tidecrest"],
            tags: ["canonical", "character", "faculty", "professor", "tidecrest", "enchantment", "objects", "illustration"]
        ),
        CharacterIllustrationProfile(
            id: "professor-permancer",
            characterName: "Professor Permancer",
            slug: "professor-permancer",
            status: "canonical",
            chapter: "Duskthorn",
            core: "Professor of Book Jumping; precise, adventurous, and fiercely safety-minded; teaches narrative weather, controlled landings, and responsible returns.",
            signature: "a many-ribboned bookmark compass and a ring of labeled door keys",
            palette: "doorway violet, safety gold, midnight ink",
            silhouette: "poised at a threshold, one hand on a bookmark compass and the other counting keys",
            continuity: "Preserve the bookmark compass, labeled keys, threshold posture, and alert measuring gaze.",
            avoid: "reckless adventurer, generic wizard, room-first composition, polished digital fantasy portrait",
            assetName: "LabyrinthCharacterProfessorPermancer",
            intendedAssetName: "LabyrinthCharacterProfessorPermancer",
            prompt: "Enchantify Academy dossier portrait in sparse graphite, ink, and watercolor: Professor Permancer at a story-door with a many-ribboned bookmark compass and labeled keys; doorway violet, safety gold, midnight ink; landing diagrams in the margins.",
            negativePrompt: "Avoid reckless action poses, glossy anime, generic fantasy wizard, and inconsistent signature objects.",
            marginalia: ["file tab labeled Professor Permancer", "signature evidence: bookmark compass and labeled door keys", "chapter mark: Duskthorn"],
            tags: ["canonical", "character", "faculty", "professor", "duskthorn", "book-jump", "threshold", "illustration"]
        )
    ]

    private static let bundledLibrary: BookReferenceLibraryPayload = {
        // A local library dropped into Documents overrides the bundled
        // one: the shipped app stays generic while a player's own lore
        // rides along as save data, not binary.
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let local = documents.appendingPathComponent("LocalReferenceLibrary.json")
            if let data = try? Data(contentsOf: local),
               let payload = try? JSONDecoder().decode(BookReferenceLibraryPayload.self, from: data) {
                return payload
            }
        }
        guard let url = Bundle.main.url(forResource: "BookReferenceLibrary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(BookReferenceLibraryPayload.self, from: data) else {
            return .empty
        }
        return payload
    }()

    static let fallbackWonderCompass: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "wonder-compass-core-loop",
            sourceID: "wonder-compass",
            title: "The Wonder Compass",
            prompt: "Try one small Compass loop.",
            body: "Notice a spark. Embark across one tiny threshold. Sense with a playful mission. Write one sentence before the moment blurs. Rest stays at the center.",
            tags: ["wonder-compass", "practice", "notice", "embark", "sense", "write", "rest"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-one-sentence",
            sourceID: "wonder-compass",
            title: "One-Sentence Souvenir",
            prompt: "Keep one bright particular.",
            body: "A single specific sentence can hold the shape of an entire day. Capture a color, sound, texture, image, or tiny mercy before your brain files it under ordinary.",
            tags: ["wonder-compass", "souvenir", "write", "memory"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-rest-center",
            sourceID: "wonder-compass",
            title: "Center Means Rest",
            prompt: "Let rest be part of the practice.",
            body: "Rest isn't failure to adventure. Rest is the center of the Compass. Some days the most radical expedition is stopping before the day breaks you.",
            tags: ["wonder-compass", "rest", "center", "care"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-dark-loop",
            sourceID: "wonder-compass",
            title: "The Compass In The Dark",
            prompt: "Use the smallest true thing.",
            body: "On hard days, the Compass gets smaller. Notice one object that isn't dying. Embark by moving one inch. Sense without judging. Write evidence: I was here.",
            tags: ["wonder-compass", "hard-day", "rest", "survival"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-shadow-wonder",
            sourceID: "wonder-compass",
            title: "Shadow Wonder",
            prompt: "Let the Compass honor what is worn, old, broken, or passing.",
            body: "The Compass isn't a filter for pretty things. Shadow Wonder uses I wonder to witness rust, decay, closed doors, grey weather, and old evidence with empathy instead of deletion.",
            tags: ["wonder-compass", "shadow-wonder", "shadow", "notice", "mono-no-aware", "duskthorn"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-playful-mission",
            sourceID: "wonder-compass",
            title: "Playful Mission",
            prompt: "Give your senses a tiny game.",
            body: "Pick an action, an adjective, and a sense: find three rough textures, listen for five tiny sounds, hunt one impossible shade of blue. Play makes attention easier to hold.",
            tags: ["wonder-compass", "sense", "play"]
        ),
        ReferenceSnippet(
            id: "wonder-compass-notes-references",
            sourceID: "wonder-compass",
            title: "Notes & References",
            prompt: "Follow the research trail behind the Wonder Compass.",
            body: "Notes & References\n\nThe Compass keeps its papers. Its trail runs through attention, awe, curiosity, habit, play, rest, memory, and the ordinary world caught doing something strange. Open the full page when you want the studies instead of the small leaf.",
            tags: ["wonder-compass", "notes", "references", "research", "back-matter"],
            url: "lore/wonder-compass-book/notes-references.md",
            preview: "The Compass keeps its papers. Open the full page when you want the research trail."
        )
    ]

    static let fallbackEnchantifyLore: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "labyrinth-lore-book-of-you",
            sourceID: "labyrinth-lore",
            title: "The Book of You",
            prompt: "Let today become a page worth keeping.",
            body: "The Book of You is the private volume that waits closest to the reader. It doesn't demand grand adventures. It notices the cup left beside the bed, the weather at the window, the sentence that would have vanished if no one had written it down. When a page is kept, the Book doesn't announce a score. It simply grows warmer, as if one more lamp has been lit in a long room.",
            tags: ["book-of-you", "memory", "private", "rooms"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-academy",
            sourceID: "labyrinth-lore",
            title: "The Academy of Unlikely Arts",
            prompt: "Step through the school-shaped margin.",
            body: "The Academy is a school built inside a living library. Its corridors behave like chapters, its classrooms keep weather of their own, and its professors tend to believe ordinary life is already enchanted but poorly indexed. Students learn by paying attention, losing their way responsibly, and returning with evidence. The school is less interested in spectacle than in whether a person can notice a true thing and carry it home intact.",
            tags: ["academy", "school", "history", "classes"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-penny-blackletter",
            sourceID: "labyrinth-lore",
            title: "Penny Blackletter",
            prompt: "Let Penny file the ridiculous evidence.",
            body: "Penny Blackletter runs the margins as if every overlooked detail might become tomorrow's headline. She writes fast, loves a field note, distrusts any sentence that arrives too polished, and has never met a strange little scrap of paper she couldn't put to work. Penny is warm under the theatrical deadlines. She believes a day isn't truly lost if one honest detail can still be recovered from it.",
            tags: ["characters", "penny", "marginalia", "letters"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-letters",
            sourceID: "labyrinth-lore",
            title: "Letters From The Margins",
            prompt: "A message can arrive from elsewhere.",
            body: "Letters in the Labyrinth don't arrive merely to explain things. They arrive with tea rings, crossed-out sentences, pressed flowers, bad timing, and the faint sense that someone hesitated before folding the page. A good letter carries relationship: what the sender wants, what they fear asking, what they noticed when the reader was elsewhere, and which door they're quietly hoping will open next.",
            tags: ["letters", "characters", "relationships", "margins"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-outer-stacks",
            sourceID: "labyrinth-lore",
            title: "The Outer Stacks",
            prompt: "Let a place become a room.",
            body: "Beyond the Academy's catalogued halls are the Outer Stacks, where real places gather room-feelings. A harbor may become a tidal reading room. A cafe may keep a tiny kingdom beneath the sugar packets. A parking lot may hold a door that only appears when the light hits the asphalt correctly. The Outer Stacks don't make places less real. They make them more themselves.",
            tags: ["outer-stacks", "location", "rooms", "place"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-rooms",
            sourceID: "labyrinth-lore",
            title: "Rooms That Behave Like Pages",
            prompt: "Open the door that has been waiting.",
            body: "Rooms in the Labyrinth aren't neutral containers. A room has a mood, a history, a preferred volume, and sometimes a private grudge against certain shoes. The Quillquarium is full of writing instruments swimming through the air until the right one chooses the right student. The Book Burrow is where lamps, blankets, snacks, and low voices make hanging out feel like a valid form of magic. The Dorm is the reader's private continuity room: shaped by kept pages, souvenirs, letters, chapter weather, and chosen comforts, but careful never to invent private facts. A Story Page can borrow any of these rooms when a day needs shape, shelter, or mischief.",
            tags: ["classes", "locations", "rooms", "story", "quillquarium", "book-burrow", "dormitory"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-instruments",
            sourceID: "labyrinth-lore",
            title: "The Instrument Law: Pens, Not Wands",
            prompt: "Ask your pen before you ask the spell.",
            body: "There are no wands at the Academy, and there never have been. Magic here is written, not waved: a spell is a sentence that means it, and the instrument that inks it does half the work. Every member of the Cast carries a writing implement (a quill, a dip pen, a pencil stub sharpened with a knife) and each implement has opinions of its own about what it's asked to write. A pen can refuse a lazy spell, improve a timid one, or add a flourish nobody ordered. This is why the Quillquarium matters: an instrument can't merely be picked up, it has to choose, and it chooses the writer it can usefully disagree with. The Headmistress's legendary inkwell is kept in her office for safekeeping. Officially.",
            tags: ["canon", "instruments", "pens", "quills", "magic", "quillquarium", "school"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-classes",
            sourceID: "labyrinth-lore",
            title: "The Compass Core Classes",
            prompt: "Let the school turn attention into practice.",
            body: "Every student eventually meets the foundation classes. Professor Lydia Boggle teaches the Art of the Glint, where ordinary objects are treated as witnesses. Professor Kyle Momort teaches Wayfinding and Narrative Kineticism, and his students learn that motion has consequences even when it begins as one step. Professor Eleanor Euphony teaches Synesthetic Resonance, where rooms have temperature, colors have weight, and the senses are given serious academic standing. Professor Vivian Villanelle teaches Ink-Binding and Souvenir Craft, where a sentence becomes a small vessel for time.",
            tags: ["classes", "faculty", "school", "schedule"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-schedule",
            sourceID: "labyrinth-lore",
            title: "The Shape of a School Day",
            prompt: "Notice the bells beneath the ordinary day.",
            body: "A school day at the Academy has a rhythm, though the building enjoys bending it. Morning classes run when the corridors are bright enough to be optimistic. Afternoon classes take the settled hours, when the Library has formed opinions and students are less easily impressed. Clubs gather under lamps in rooms that pretend not to be listening. Between these formal hours are the true passages: breakfast gossip, corridor weather, the note slipped under a door, and the friend waiting outside the room with a question folded into silence.",
            tags: ["classes", "schedule", "school", "student-life"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-headmistress-thorne",
            sourceID: "labyrinth-lore",
            title: "Headmistress Seraphina Thorne",
            prompt: "Let authority enter with a hidden page.",
            body: "Headmistress Seraphina Thorne has the poise of someone who can silence a room by closing a book. Students see the elegant robes, the precise speech, the old authority of a person who knows which staircases lie. What they don't always see is the cost of keeping a school safe when the school itself is a living text with strong opinions and a long memory. Thorne isn't soft, but she isn't careless. Her office contains a legendary inkwell, officially for safekeeping. Unofficially, students suspect she uses it after midnight. There's always, around her, the faint cold draft of a window left open onto winter, though no one has ever found the window.",
            tags: ["characters", "faculty", "headmistress", "history", "duskthorn"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-history",
            sourceID: "labyrinth-lore",
            title: "Unreliable Academy History",
            prompt: "Let the old stories misbehave politely.",
            body: "Academy history is full of incidents recorded with suspiciously careful handwriting. During the Day of the Living Literary Figures, Sherlock Holmes, Alice, and Dracula appeared in the cafeteria at the same time; Holmes deduced the menu, Alice critiqued the architecture, and Dracula objected to the lighting. The Pages of Laughter and Tears once made an entire class alternate between hysterics and sobbing until someone discovered the comedy and tragedy pages had been shelved out of order. These stories are told as warnings, but students mostly hear invitations.",
            tags: ["academy", "history", "school", "story"]
        ),
        ReferenceSnippet(
            id: "labyrinth-lore-weather",
            sourceID: "labyrinth-lore",
            title: "Weather in the Stacks",
            prompt: "Let the sky annotate the page.",
            body: "Weather at the Academy is never only meteorological, but it's never merely symbolic either. Fog makes professors cancel class to watch the harbor disappear by degrees. Rain turns corridors into quieter arguments. Bright cold sharpens the ink. Heat makes the paper curl and the students theatrical. The Library cloud above the great ceiling changes color when the building is thinking about something it doesn't intend to say aloud. A weather page should remain legible, but the Book may name the mood of the response. The reader should feel tended, not watched.",
            tags: ["atmosphere", "school", "weather", "world"]
        )
    ]

    /// The Shadow Wonder shelf: the Dusk Thorn's reading list. Real-world folklore
    /// and the canon's "harmonize with the grey" practice, framed the way the
    /// Labyrinth frames everything: as tradition to witness, not instruction to
    /// obey. Surfaced as Shadow Lore variants when the Dusk Thorn is invested in
    /// and the world turns toward the worn edge. Each carries a small, safe
    /// `practice`: an offering, a noticing, a threshold to honor.
    static let fallbackShadowLore: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "shadow-lore-what-it-is",
            sourceID: "labyrinth-lore",
            title: "Shadow Wonder",
            prompt: "The Dusk Thorn names wonder with an honest edge.",
            body: "Duskthorn doesn't ask me to become cruel. It asks me to stop sanding the edges off reality. Shadow Wonder is the practice of noticing rust, absence, decay, closed doors, old evidence, and grey weather as things with history instead of mistakes to delete. The bright Compass finds the sunset. The dark Compass finds the abandoned house going beautifully back to ivy, and refuses to look away.",
            tags: ["lore", "shadow-wonder", "shadow", "duskthorn", "talisman", "mono-no-aware"],
            practice: "Find one broken, worn, or closed thing nearby and ask it a single honest \"I wonder\", about its history, not its repair."
        ),
        ReferenceSnippet(
            id: "shadow-lore-unseelie-court",
            sourceID: "labyrinth-lore",
            title: "The Unseelie Court",
            prompt: "Meet the winter half of the fae.",
            body: "Old folklore splits the fae into two courts. The Seelie are the bright, summer-tempered ones, mischievous but inclined to be kind if you are. The Unseelie are the dark court: winter, dusk, and the long night. They aren't evil so much as unsentimental: they keep the rules that bright things forget, and they don't pretend the world is gentle when it isn't. Duskthorn keeps a quiet correspondence with them. The Labyrinth files them under Shadow Wonder for a reason (they're proof that something can be dangerous, beautiful, and worth respecting all at once. And if you ever want to know what one looks like wearing a crown of office) here Penny lowers her voice: watch which staircases lie when a certain Headmistress walks them. Then she changes the subject.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "fae", "duskthorn", "thorne", "folklore", "night"]
        ),
        ReferenceSnippet(
            id: "shadow-lore-dealing-with-unseelie",
            sourceID: "labyrinth-lore",
            title: "Dealing With the Unseelie",
            prompt: "Honest manners with dangerous guests.",
            body: "Folklore is full of etiquette for the dark court, and it's mostly about honesty and boundaries. That's why Duskthorn approves of it. Don't say a flat \"thank you,\" which can read as a debt admitted; say \"I'm grateful\" or \"you were kind to me\" instead. Don't give your true name to something that asks too eagerly. Don't eat what is offered until you know its price. Keep your promises exactly, because the Unseelie keep theirs exactly. Offer hospitality and you'll usually receive it back. The rules aren't superstition; they're an old, sideways lesson in not being careless with powerful things, or powerful people.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "fae", "duskthorn", "folklore", "protection", "boundaries"],
            practice: "Tonight, practice one fae-court manner in the real world: thank someone with \"that was kind of you\" instead of a reflexive \"thanks,\" and notice how differently it lands."
        ),
        ReferenceSnippet(
            id: "shadow-lore-the-headmistress",
            sourceID: "labyrinth-lore",
            title: "Which Staircases Lie",
            prompt: "A rumour the sorting ledger won't hold.",
            body: "Here is a thing the Labyrinth never says aloud, and Penny only ever says sideways. The Headmistress's name is Thorne. The talisman of the dark chapter is the Dusk Thorn. The chapter itself (Duskthorn) keeps no founder in the sorting ledger and no door anyone will point to. Draw the line yourself, or don't. Seraphina Thorne sees the Unwritten, keeps star-cold eyes, wears her hair pinned like a dark crown, and is said to use her inkwell only after midnight. The Unseelie guard their true names for a reason; she guards an entire court behind a school. Nothing is confirmed, you understand. It's only that the west windows go violet at dusk, and the staircases she walks have a quiet habit of lying.",
            tags: ["lore", "shadow-wonder", "shadow", "unseelie", "thorne", "duskthorn", "secret", "folklore", "night"],
            practice: "Notice one figure of authority you've only ever seen from the front. Wonder, once and without deciding anything, what they might be guarding when no one is watching."
        ),
        ReferenceSnippet(
            id: "shadow-lore-correspondences",
            sourceID: "labyrinth-lore",
            title: "The Table of Correspondences",
            prompt: "How the old craft sorts the world.",
            body: "Folk witchcraft keeps a table of correspondences: a way of saying which things rhyme with which. Iron and salt for protection; rosemary for memory; rue and rowan for warding; mugwort for dreams; the waning moon for release and the dark moon for rest and secrets; black for banishing and absorbing, deep violet for the threshold between. None of it's a vending machine. It's a memory system, a way of making an intention concrete enough to hold. That's exactly what a One-Sentence Souvenir does. Shadow Wonder treats a correspondence the way it treats rust: as a real pattern worth witnessing, not a wish worth believing in blindly.",
            tags: ["lore", "shadow-wonder", "shadow", "correspondences", "witchcraft", "folklore", "herbs", "moon"],
            practice: "Pick one correspondence and make it literal: set a pinch of salt or a sprig of rosemary somewhere you'll see it, and let it stand for one thing you want to protect or remember this week."
        ),
        ReferenceSnippet(
            id: "shadow-lore-iron-salt-rowan",
            sourceID: "labyrinth-lore",
            title: "Iron, Salt, and Rowan",
            prompt: "The old protective charms.",
            body: "Three protections turn up in nearly every European folk tradition: cold iron (a nail, a key, a horseshoe over the door), salt (scattered at a threshold or carried in a pocket), and rowan wood with red thread. They were hung at doors and windows (the liminal places) because that's where folklore believed the world was thinnest. Modern eyes can read them plainly: small, deliberate objects that say I'm paying attention to the edges of my home. Shadow Wonder doesn't need you to believe a horseshoe stops a spirit. It only asks you to notice that humans have always marked their thresholds, and to wonder why that comforts us still.",
            tags: ["lore", "shadow-wonder", "shadow", "protection", "iron", "salt", "rowan", "folklore", "threshold"],
            practice: "Find the iron already in your home (a key, a cast pan, a nail) and place it deliberately by a door for one night. Notice whether a guarded threshold changes how the room feels."
        ),
        ReferenceSnippet(
            id: "shadow-lore-between-hours",
            sourceID: "labyrinth-lore",
            title: "The Between Hours",
            prompt: "Dusk, midnight, and the thin times.",
            body: "Folklore marks certain hours as liminal: neither one thing nor the other, and therefore powerful. Dusk and dawn, the seams of the day. Midnight, the seam of the date. The threshold of a door, neither in nor out. The dark moon, when the sky keeps its own counsel. These are the Unseelie's hours, and Duskthorn's. The Wonder Compass has always said the same thing in plainer words: the in-between is where attention sharpens, because the brain can no longer run on autopilot. A doorway is a small dusk. A held breath is a small midnight.",
            tags: ["lore", "shadow-wonder", "shadow", "liminal", "night", "dusk", "folklore", "threshold"],
            practice: "At the next dusk, stop where you are for one minute and let the light change without fixing it. Write the exact color the sky turns as it crosses over."
        ),
        ReferenceSnippet(
            id: "shadow-lore-mono-no-aware",
            sourceID: "labyrinth-lore",
            title: "Mono no Aware",
            prompt: "The beauty that depends on ending.",
            body: "The Japanese phrase mono no aware names the gentle ache of things that pass: falling petals, a friend's car turning the corner, the last warm afternoon before the cold. It's the heart of Shadow Wonder. Not sadness exactly, and never despair: a deepening. The cherry blossom is beloved precisely because it doesn't last. Duskthorn would put it bluntly: a story with no ending has no stakes, and a day you could keep forever you would never actually look at. The grey isn't the enemy of wonder. Half of wonder lives there.",
            tags: ["lore", "shadow-wonder", "shadow", "mono-no-aware", "grief", "memory", "duskthorn", "philosophy"],
            practice: "Find one thing nearby that's quietly ending (light, a season, a flower, a cup going cold) and keep a single sentence for it before it goes."
        ),
        ReferenceSnippet(
            id: "shadow-lore-goblin-market",
            sourceID: "labyrinth-lore",
            title: "The Goblin Market",
            prompt: "Every bargain names its price.",
            body: "Beneath the Labyrinth runs the Goblin Market, where the Unseelie trade and the prices are always honest even when they're steep. The oldest rule of the market is the one the bright world keeps forgetting: nothing is free, and the things that pretend to be free cost the most. A goblin will tell you the price up front. That's more than the grey ever does. Shadow Wonder borrows the market's clear eyes: it asks, of a glowing offer or a numbing habit, the goblin's only question: and what does this actually cost me?",
            tags: ["lore", "shadow-wonder", "shadow", "goblin", "unseelie", "market", "bargain", "folklore"],
            practice: "Name one \"free\" thing in your day (a scroll, a shortcut, a numbing) and write its real, hidden price in one honest line."
        ),
        ReferenceSnippet(
            id: "shadow-lore-true-names",
            sourceID: "labyrinth-lore",
            title: "True Names",
            prompt: "What is named can be held.",
            body: "Across folklore, to know a thing's true name is to have power over it. That's why the fae guard theirs and why naming a fear out loud has always been the first step toward facing it. The Unseelie will trade in everything but their names. Shadow Wonder works the same lever in the other direction: the grey, the dread, the heavy mood keeps its power only while it stays unnamed and shapeless. Say the true name of what is sitting on your chest, exactly, and it stops being weather and becomes a thing with edges you can finally see around.",
            tags: ["lore", "shadow-wonder", "shadow", "true-names", "fae", "naming", "folklore", "grief"],
            practice: "Give one heavy, vague feeling its exact true name, not \"bad,\" but the precise word. Write the name and notice if the weight shifts once it has edges."
        ),
        ReferenceSnippet(
            id: "shadow-lore-offerings",
            sourceID: "labyrinth-lore",
            title: "Offerings and Hospitality",
            prompt: "The oldest courtesy left at the threshold.",
            body: "The kindest folklore about the dark court is also the simplest: leave something out. A saucer of milk, a spoon of honey, a crust of bread on the windowsill or the back step. The offering was never really about feeding spirits. It was a nightly act of generosity toward the unseen and the unrepaid: a way of practicing hospitality even when no one was watching to thank you for it. Duskthorn respects it because it costs something small and asks for nothing back. Shadow Wonder counts that as one of its quietest adventures: give a gift the world will never confirm it received.",
            tags: ["lore", "shadow-wonder", "shadow", "offering", "hospitality", "fae", "folklore", "kindness"],
            practice: "Leave one small, genuine offering tonight with no audience: crumbs for the birds, a saucer on the sill, a kindness no one will trace back to you."
        ),
        ReferenceSnippet(
            id: "shadow-lore-shadow-self",
            sourceID: "labyrinth-lore",
            title: "The Shadow You Disowned",
            prompt: "Witness the part you keep in the dark.",
            body: "Old stories are full of disowned things that grow dangerous only because they were locked away: the uninvited thirteenth guest, the cellar no one opens, the name never spoken. The lesson repeats: what you refuse to look at runs your house from the dark. Shadow Wonder isn't brooding and it isn't wallowing. It's the simple, brave act of turning the lamp toward the thing you usually file under \"ugly, delete\", the rust, the regret, the unflattering want) and witnessing it without flinching or fixing. The Unseelie respect that. So does the part of you that has been waiting to be seen.",
            tags: ["lore", "shadow-wonder", "shadow", "shadow-self", "grief", "folklore", "psychology", "duskthorn"],
            practice: "Notice one small thing about today you'd rather not look at, and look at it for ten honest seconds: no fixing, no verdict. Write what you actually saw."
        )
    ]

    static let fallbackPatreon: [ReferenceSnippet] = [
        ReferenceSnippet(
            id: "creator-notes-retired",
            sourceID: "patreon-packet",
            title: "Creator Notes",
            prompt: "The public shelf is retired.",
            body: "Creator support notes are retired from my daily pages. I keep my attention on your own pages.",
            tags: ["creator-notes", "retired"]
        )
    ]

    static func dailyWonderCompassSnippet(for day: BookDay, now: Date = Date()) -> ReferenceSnippet {
        snippet(from: wonderCompass, dayID: day.id, sourceID: "wonder-compass", now: now)
    }

    static func relevantWonderCompassSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date()
    ) -> ReferenceSnippet {
        relevantWonderCompassSnippets(for: day, inputs: inputs, now: now, limit: 1).first
            ?? dailyWonderCompassSnippet(for: day, now: now)
    }

    static func rotatingWonderCompassSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        let pool = relevantWonderCompassSnippets(for: day, inputs: inputs, now: now, limit: 8)
        return rotatedSnippet(from: pool, day: day, sourceID: "wonder-compass", now: now, manual: manual)
            ?? dailyWonderCompassSnippet(for: day, now: now)
    }

    static func relevantWonderCompassSnippets(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        limit: Int = 8
    ) -> [ReferenceSnippet] {
        let snippets = wonderCompass.filter { !$0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
        guard !snippets.isEmpty else { return [] }

        let contextTerms = wonderCompassContextTerms(for: day, inputs: inputs, now: now)
        let rotationSlot = referenceRotationSlot(for: now)
        let recentKeys = inputs.recentVarietyKeys(now: now)
        // The tie-break seed is decorated onto each row rather than computed
        // inside the comparator, which built and hashed two strings per
        // comparison.
        let scored = snippets.enumerated().map { offset, snippet in
            var score = ReferenceHaystackCache.matchCount(for: snippet, terms: contextTerms)
            // A chapter the reader was just shown yields the lectern.
            if recentKeys.contains("snippet:\(snippet.id)") {
                score -= 3
            }
            let seed = stableIndex(
                for: "\(day.id)-\(rotationSlot)-\(snippet.id)-wonder-compass-relevance",
                count: 10_000
            )
            return (offset: offset, snippet: snippet, score: score, seed: seed)
        }

        return scored
            .sorted { left, right in
                if left.score == right.score {
                    if left.seed == right.seed {
                        return left.offset < right.offset
                    }
                    return left.seed < right.seed
                }
                return left.score > right.score
            }
            .prefix(max(1, limit))
            .map(\.snippet)
    }

    static func dailyEnchantifyLoreSnippet(for day: BookDay, now: Date = Date()) -> ReferenceSnippet {
        snippet(from: enchantifyLore, dayID: day.id, sourceID: "labyrinth-lore", now: now)
    }

    static func relevantLoreSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date()
    ) -> ReferenceSnippet {
        relevantLoreSnippets(for: day, inputs: inputs, now: now, limit: 1).first
            ?? dailyEnchantifyLoreSnippet(for: day, now: now)
    }

    static func rotatingLoreSnippet(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        let pool = relevantLoreSnippets(for: day, inputs: inputs, now: now, limit: 8)
        return rotatedSnippet(from: pool, day: day, sourceID: "labyrinth-lore", now: now, manual: manual)
            ?? dailyEnchantifyLoreSnippet(for: day, now: now)
    }

    /// The Dusk Thorn's shelf: bundled shadow-tagged lore plus the fallback pool.
    static var shadowLore: [ReferenceSnippet] {
        let bundled = enchantifyLore.filter { $0.tags.map { $0.lowercased() }.contains("shadow-wonder") }
        return bundled.isEmpty ? fallbackShadowLore : bundled
    }

    /// One Shadow Wonder lore card, rotated through the dark shelf so the Unseelie
    /// etiquette, the correspondences, and the rest take turns rather than repeating.
    static func rotatingShadowLoreSnippet(
        for day: BookDay,
        now: Date = Date(),
        manual: Bool = false
    ) -> ReferenceSnippet {
        rotatedSnippet(from: shadowLore, day: day, sourceID: "labyrinth-lore-shadow", now: now, manual: manual)
            ?? fallbackShadowLore.first
            ?? snippet(from: shadowLore, dayID: day.id, sourceID: "labyrinth-lore-shadow", now: now)
    }

    static func relevantLoreSnippets(
        for day: BookDay,
        inputs: BookSourceInputs = .empty,
        now: Date = Date(),
        limit: Int = 6
    ) -> [ReferenceSnippet] {
        let snippets = enchantifyLore
        guard !snippets.isEmpty else { return [] }

        let contextTerms = loreContextTerms(for: day, inputs: inputs, now: now)
        let rotationSlot = referenceRotationSlot(for: now)
        let recentKeys = inputs.recentVarietyKeys(now: now)
        let scored = snippets.enumerated().map { offset, snippet in
            var score = ReferenceHaystackCache.matchCount(for: snippet, terms: contextTerms)
            if recentKeys.contains("snippet:\(snippet.id)") {
                score -= 3
            }
            let seed = stableIndex(
                for: "\(day.id)-\(rotationSlot)-\(snippet.id)-labyrinth-lore-relevance",
                count: 10_000
            )
            return (offset: offset, snippet: snippet, score: score, seed: seed)
        }

        return scored
            .sorted { left, right in
                if left.score == right.score {
                    if left.seed == right.seed {
                        return left.offset < right.offset
                    }
                    return left.seed < right.seed
                }
                return left.score > right.score
            }
            .prefix(max(1, limit))
            .map(\.snippet)
    }

    static func patreonShelfSnippet(now: Date = Date()) -> ReferenceSnippet {
        snippet(from: patreon, dayID: currentDayID(now), sourceID: "patreon-packet", now: now)
    }

    static func rotatingPatreonShelfSnippet(for day: BookDay, now: Date = Date(), manual: Bool = false) -> ReferenceSnippet {
        let pool = patreon.isEmpty ? [] : patreon
        return rotatedSnippet(from: pool, day: day, sourceID: "patreon-packet", now: now, manual: manual)
            ?? patreonShelfSnippet(now: now)
    }

    static func patreonPostSnippets(limit: Int = 6, now: Date = Date()) -> [ReferenceSnippet] {
        let posts = patreon
            .filter { snippet in
                snippet.url?.isEmpty == false
                    || snippet.body.range(of: "https://", options: [.caseInsensitive]) != nil
                    || snippet.body.range(of: "http://", options: [.caseInsensitive]) != nil
            }
            .sorted { left, right in
                let leftDate = left.publishedAt ?? ""
                let rightDate = right.publishedAt ?? ""
                if leftDate == rightDate {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return leftDate > rightDate
            }
        guard !posts.isEmpty else { return [] }
        return Array(posts.prefix(max(1, limit)))
    }

    static func labyrinthIllustration(for day: BookDay, now: Date = Date()) -> LabyrinthIllustrationPlate {
        guard !labyrinthIllustrations.isEmpty else {
            return LabyrinthIllustrationPlate(
                id: "empty",
                assetName: "",
                title: "Illustration",
                caption: "The illustration shelf is empty for now.",
                note: "Add character dossier assets to wake this page.",
                tags: ["illustration"]
            )
        }
        let seed = "\(day.id)-labyrinth-illustrations-\(referenceRotationSlot(for: now, hours: 1))"
        return labyrinthIllustrations[stableIndex(for: seed, count: labyrinthIllustrations.count)]
    }

    static func rotatingLabyrinthIllustration(for day: BookDay, now: Date = Date(), manual: Bool = false) -> LabyrinthIllustrationPlate {
        guard !labyrinthIllustrations.isEmpty else {
            return labyrinthIllustration(for: day, now: now)
        }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let seed = "\(day.id)-labyrinth-illustrations-\(slot)-\(manual ? "manual" : "curator")"
        return labyrinthIllustrations[stableIndex(for: seed, count: labyrinthIllustrations.count)]
    }

    private static func rotatedSnippet(
        from snippets: [ReferenceSnippet],
        day: BookDay,
        sourceID: String,
        now: Date,
        manual: Bool
    ) -> ReferenceSnippet? {
        guard !snippets.isEmpty else { return nil }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let seed = "\(day.id)-\(sourceID)-\(slot)-\(manual ? "manual" : "curator")"
        return snippets[stableIndex(for: seed, count: snippets.count)]
    }

    static func characterIllustrationProfile(id: String?) -> CharacterIllustrationProfile? {
        guard let id else { return nil }
        return characterIllustrations.first { $0.id == id }
    }

    static func firstURL(in snippet: ReferenceSnippet) -> String? {
        snippet.url?.isEmpty == false ? snippet.url : firstURL(in: snippet.body)
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }

    private static func currentDayID(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func snippet(from snippets: [ReferenceSnippet], dayID: String, sourceID: String, now: Date) -> ReferenceSnippet {
        guard !snippets.isEmpty else {
            return ReferenceSnippet(
                id: "\(sourceID)-empty",
                sourceID: sourceID,
                title: "Reference Page",
                prompt: "A reference page is waiting.",
                body: "I know this shelf exists, but no snippets have been loaded yet.",
                tags: [sourceID]
            )
        }

        let seed = "\(dayID)-\(sourceID)-\(referenceRotationSlot(for: now))"
        let index = stableIndex(for: seed, count: snippets.count)
        return snippets[index]
    }

    private static func referenceRotationSlot(for date: Date, hours: Int = 2, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour], from: date)
        return (components.hour ?? 0) / max(1, hours)
    }

    private static func wonderCompassContextTerms(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [String] {
        var terms: Set<String> = ["wonder", "notice"]
        let hour = Calendar.current.component(.hour, from: now)

        if hour >= 18 {
            terms.formUnion(["souvenir", "write", "memory", "sentence"])
        }
        if hour >= 20 {
            terms.formUnion(["rest", "center", "care"])
        }

        for page in day.capturedPages {
            terms.formUnion(page.tags.map { $0.lowercased() })
            let lowered = page.userInput.lowercased()
            if lowered.contains("tired") || lowered.contains("low") || lowered.contains("hard") || lowered.contains("heavy") {
                terms.formUnion(["rest", "care", "hard-day"])
            }
            if lowered.contains("walk") || lowered.contains("outside") || lowered.contains("errand") {
                terms.formUnion(["embark", "practice"])
            }
            if lowered.contains("saw") || lowered.contains("heard") || lowered.contains("felt") || lowered.contains("smell") {
                terms.formUnion(["sense", "notice"])
            }
            if lowered.contains("remember") || lowered.contains("moment") || lowered.contains("today") {
                terms.formUnion(["souvenir", "write", "memory"])
            }
            if lowered.contains("play") || lowered.contains("fun") || lowered.contains("silly") {
                terms.formUnion(["play", "mission"])
            }
        }

        if let body = inputs.body {
            let lowered = "\(body.status) \(body.phrase)".lowercased()
            if body.score > 0 && body.score <= 35 || lowered.contains("low") || lowered.contains("gentle") {
                terms.formUnion(["rest", "center", "care", "hard-day"])
            }
        }

        if let weather = inputs.weather {
            let lowered = weather.phrase.lowercased()
            if lowered.contains("rain") || lowered.contains("fog") || lowered.contains("storm") {
                terms.formUnion(["sense", "notice", "rest"])
            }
            if lowered.contains("sun") || lowered.contains("bright") || lowered.contains("clear") {
                terms.formUnion(["embark", "play", "notice"])
            }
        }

        for fact in inputs.selfFacts where fact.usePermission != .doNotUse {
            terms.formUnion(fact.tags.map { $0.lowercased() })
            let lowered = "\(fact.question) \(fact.answer)".lowercased()
            if lowered.contains("home") {
                terms.formUnion(["home", "rest", "care"])
            }
            if lowered.contains("color") || lowered.contains("delight") || lowered.contains("joy") {
                terms.formUnion(["play", "wonder", "notice"])
            }
            if lowered.contains("rest") || lowered.contains("quiet") || lowered.contains("sleep") {
                terms.formUnion(["rest", "center", "care"])
            }
            if lowered.contains("believe") || lowered.contains("protect") || lowered.contains("become") {
                terms.formUnion(["belief", "practice", "memory"])
            }
        }

        return Array(terms)
    }

    private static func loreContextTerms(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [String] {
        var terms = Set(wonderCompassContextTerms(for: day, inputs: inputs, now: now))
        terms.formUnion(["academy", "book", "characters", "lore", "rooms", "school", "story"])

        let hour = Calendar.current.component(.hour, from: now)
        if hour < 11 {
            terms.formUnion(["schedule", "classes", "today"])
        } else if hour >= 18 {
            terms.formUnion(["letters", "dormitory", "student-life"])
        }

        if inputs.weather != nil {
            terms.formUnion(["weather", "atmosphere"])
        }
        if inputs.body != nil {
            terms.formUnion(["body", "care"])
        }
        if inputs.selfFacts.contains(where: { $0.usePermission != .doNotUse && $0.tags.contains("home") }) {
            terms.formUnion(["home", "dormitory", "rooms"])
        }

        return Array(terms)
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let value = seed.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
        return Int(value % UInt64(count))
    }
}

struct QuipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .quip)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        quipSurface(for: day, context: context, inputs: inputs, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let baseTags = referenceTags(inputs: inputs)
        let shadowVisitsQuips = ShadowWonder.shouldSurface(.quip, inputs: inputs, now: now)
        let brightLimit = inputs.catalogueCandidateLimit(shadowVisitsQuips ? 2 : 4)
        var pages = QuipPackRegistry.rankedQuips(
            for: day,
            now: now,
            tags: baseTags,
            limit: brightLimit
        ).map {
            quipSurface(for: day, context: context, inputs: inputs, now: now, manual: false, selectedQuip: $0)
        }
        if shadowVisitsQuips {
            let brightID = pages.first?.id
            pages += QuipPackRegistry.rankedQuips(
                for: day,
                now: now,
                tags: baseTags + ShadowWonder.tags(inputs: inputs, now: now),
                limit: inputs.catalogueCandidateLimit(2)
            ).map {
                quipSurface(
                    for: day,
                    context: context,
                    inputs: inputs,
                    now: now,
                    manual: false,
                    selectedQuip: $0,
                    shadowVariantOf: brightID
                )
            }
        }
        var seen = Set<String>()
        return pages.filter { page in
            guard let id = page.payload.metadata["quipID"] else { return true }
            return seen.insert(id).inserted
        }
    }

    private func quipSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        manual: Bool,
        selectedQuip: QuipEntry? = nil,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
            + (isShadowVariant ? ShadowWonder.tags(inputs: inputs, now: now) : [])
        let quip = selectedQuip ?? QuipPackRegistry.quip(
            for: day,
            now: manual ? now.addingTimeInterval(Double(Int.random(in: 1...10_000))) : now,
            tags: tags
        )
        let hour = Calendar.current.component(.hour, from: now)
        let score = (context.distress.isActive ? 42 : (hour >= 12 && hour <= 18 ? 69 : 58)) + (isShadowVariant ? shadowState.scoreBoost : 0)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let baseTags = quip.tags.joined(separator: ",")
        var metadata = [
            "source": source.id,
            "packID": quip.packID,
            "quipID": quip.id,
            "tags": isShadowVariant ? ShadowWonder.mergedTags(baseTags, inputs: inputs, now: now) : baseTags,
            "privacy": "bundled local text"
        ]
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(quip.packID)-\(quip.id)-\(slotID)",
            type: .quip,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: score,
            reason: isShadowVariant ? "This Shadow Wonder quip variant tilts the day toward the dark edge without pretending it's bright." : "A small oddity can tilt the day toward wonder without asking for work.",
            prompt: isShadowVariant ? "Shadow Quip: \(quip.title)" : quip.title,
            detail: "A little perspective-spark from \(QuipPackRegistry.enabledPacks.first { $0.id == quip.packID }?.displayName ?? "the shelf").",
            payload: BookPagePayload(
                headline: quip.title,
                body: quip.text,
                metadata: metadata
            )
        )
    }

    private func referenceTags(inputs: BookSourceInputs) -> [String] {
        [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
    }
}

struct QuotesPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .quotes)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        quoteSurface(for: day, context: context, inputs: inputs, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let tags = referenceTags(inputs: inputs)
        return QuoteLibraryRegistry.rankedQuotes(for: day, now: now, tags: tags, limit: inputs.catalogueCandidateLimit(4)).map {
            quoteSurface(
                for: day,
                context: context,
                inputs: inputs,
                now: now,
                manual: false,
                selectedQuote: $0
            )
        }
    }

    private func quoteSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        manual: Bool,
        selectedQuote: QuoteEntry? = nil
    ) -> SurfacePage {
        let tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
        let quote = selectedQuote ?? QuoteLibraryRegistry.quote(
            for: day,
            now: manual ? now.addingTimeInterval(Double(Int.random(in: 1...10_000))) : now,
            tags: tags
        )
        let hour = Calendar.current.component(.hour, from: now)
        // A quote sits well any time, but leans into the reflective afternoon and
        // the quiet of evening. Gentler than a quip when the day is heavy.
        let score = context.distress.isActive ? 48 : ((hour >= 11 && hour <= 21) ? 66 : 58)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 40)
        let attribution = quote.attributionLine
        return SurfacePage(
            id: "\(source.id)-\(quote.packID)-\(quote.id)-\(slotID)",
            type: .quotes,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: score,
            reason: "A line worth keeping near the desk: on wonder, attention, and this one precious life.",
            prompt: quote.text,
            detail: attribution,
            payload: BookPagePayload(
                headline: quote.theme,
                body: attribution,
                metadata: [
                    "source": source.id,
                    // The quotation itself lives in `prompt`, and the folio
                    // titles a Page from its `headline` unless the Page owns a
                    // response box — which printed "Attention · William Blake"
                    // and no quote at all. The line is the Page; it gets the
                    // title. See `FolioLeafComposer`.
                    "folioTitle": quote.text,
                    "packID": quote.packID,
                    "quoteID": quote.id,
                    "quote": quote.text,
                    "quoteAuthor": quote.author,
                    "quoteSource": quote.source ?? "",
                    "quoteTheme": quote.theme,
                    "surfaceLabel": "Quotes",
                    "tags": (["quote", quote.theme.lowercased()] + quote.tags).joined(separator: ","),
                    "privacy": "bundled local text"
                ]
            )
        )
    }

    private func referenceTags(inputs: BookSourceInputs) -> [String] {
        [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
    }
}

struct AffirmationsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .affirmations)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        affirmationSurface(for: day, context: context, inputs: inputs, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let tags = referenceTags(inputs: inputs, distressActive: context.distress.isActive)
        var lastShown: [String: Date] = [:]
        for entry in AffirmationLibraryRegistry.allAffirmations {
            if let record = inputs.surfaceHistory["affirmation:\(entry.id)"] {
                lastShown[entry.id] = record.lastShownAt
            }
        }
        return AffirmationLibraryRegistry.rankedAffirmations(
            for: day,
            now: now,
            tags: tags,
            limit: inputs.catalogueCandidateLimit(4),
            lastShown: lastShown
        ).map {
            affirmationSurface(
                for: day,
                context: context,
                inputs: inputs,
                now: now,
                manual: false,
                selectedAffirmation: $0
            )
        }
    }

    private func affirmationSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        manual: Bool,
        selectedAffirmation: AffirmationEntry? = nil
    ) -> SurfacePage {
        var tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
        // On a heavy day the Book leans toward the gentle shelf and asks for
        // nothing: a gift, not homework.
        if context.distress.isActive {
            tags += ["gentle", "hard-day", "rest", "gift"]
        }
        let entry = selectedAffirmation ?? AffirmationLibraryRegistry.affirmation(
            for: day,
            now: manual ? now.addingTimeInterval(Double(Int.random(in: 1...10_000))) : now,
            tags: tags
        )
        let hour = Calendar.current.component(.hour, from: now)
        let score = context.distress.isActive ? 62 : ((hour >= 5 && hour < 11) ? 68 : 58)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 40)
        return SurfacePage(
            id: "\(source.id)-\(entry.packID)-\(entry.id)-\(slotID)",
            type: .affirmations,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: score,
            reason: entry.isPact
                ? "I want one small agreement. Sign it, change it, or cross it out."
                : "I wanted you to have this. Nothing's owed.",
            prompt: entry.text,
            detail: entry.aside,
            payload: BookPagePayload(
                headline: entry.theme,
                body: entry.text,
                metadata: [
                    "source": source.id,
                    // Same as the Quotes Page: the believing is `prompt`, the
                    // theme is a shelf label. Without this the leaf reads
                    // "Courage" over the Book's aside, and the line the Book
                    // actually wanted to say never reaches paper.
                    "folioTitle": entry.text,
                    "packID": entry.packID,
                    "affirmationID": entry.id,
                    // The Curator rests a Page for as long as its family takes
                    // to come round once, and it can only count the four it is
                    // offered. The family is the whole shelf.
                    "deckSize": "\(AffirmationLibraryRegistry.allAffirmations.count)",
                    "affirmationKind": entry.isPact ? "pact" : "gift",
                    "countersigns": entry.countersigns.joined(separator: "||"),
                    "placeholder": entry.placeholder,
                    "surfaceLabel": "Believing",
                    "tags": (["affirmation", entry.theme.lowercased()] + entry.tags).joined(separator: ","),
                    "privacy": "bundled local text"
                ]
            )
        )
    }

    private func referenceTags(inputs: BookSourceInputs, distressActive: Bool) -> [String] {
        var tags = [
            inputs.weather?.phrase,
            inputs.body?.status,
            inputs.selectedWonderCompass?.tags.joined(separator: ",")
        ]
            .compactMap(\.self)
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init) }
        if distressActive {
            tags += ["gentle", "hard-day", "rest", "gift"]
        }
        return tags
    }
}

/// Resolves a character (by display name) to its official illustration profile:
/// the bundled portrait asset when one exists, and always the described palette,
/// signature, and core so a themed medallion can stand in where art doesn't yet.
enum CharacterPortrait {
    static func profile(forName name: String) -> CharacterIllustrationProfile? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !target.isEmpty else { return nil }
        return BookReferenceCatalog.characterIllustrations.first {
            $0.characterName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }

    /// The asset name this character's art *would* use. The view checks whether
    /// that image actually exists in the catalog, so dropping a generated PNG in
    /// is the only step needed to light up a portrait, no Swift edits.
    static func intendedAssetName(forName name: String) -> String? {
        guard let profile = profile(forName: name) else { return nil }
        return profile.assetName?.nonEmpty ?? profile.intendedAssetName.nonEmpty
    }

    /// The bundled image asset for this character, or nil if only a description
    /// exists (use the medallion fallback then).
    static func bundledAssetName(forName name: String) -> String? {
        guard let profile = profile(forName: name) else { return nil }
        let asset = profile.assetName?.nonEmpty ?? profile.intendedAssetName
        return BookReferenceCatalog.bundledCharacterIllustrationAssetNames.contains(asset) ? asset : nil
    }

    /// The character's official palette words (e.g. "ink black, old silver"),
    /// for tinting a fallback medallion.
    static func paletteWords(forName name: String) -> [String] {
        (profile(forName: name)?.palette ?? "")
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    static func initials(forName name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

/// Hand-authored, longer dossier prose for the canonical Cast: one bespoke
/// entry per surfacing character illustration plate, keyed by the profile's
/// `slug`. The Book speaks each one in its own voice, drawing on the character's
/// traits, quirks, fault, longing, and signature object so no two read alike.
/// When a slug is present here, the plate uses it verbatim; everything else
/// (locations, talismans, Book Fae, and any character without bespoke prose)
/// falls back to the generated dossier in `LabyrinthIllustrationPageSourceAdapter`.
enum CastDossier {
    static func bio(forSlug slug: String) -> String? {
        bios[slug]
    }

    static let bios: [String: String] = [
        "pippa-pilcrow": "Pippa Pilcrow tickles the margins until the punctuation gives up and runs wild. Professor Mook keeps the words at their posts. Pippa shows up like a held breath finally let go, and every sentence in the room starts reaching for a meaning nobody gave it. She's delighted, quick, and light as a comma. The Registry files her under *menace*. They say it fondly. They'll regret the full stop.\n\nShe's the chaos in the rebellion and she isn't sorry. Her creed is four words, *words set free*, and she means it the way kids mean a dare. Here's what I watch. She can't always tell a word that's longing to change from a word that only needed a bit of mercy, and when she's thrilled she'll pull loose a word that wanted to stay put. Delight can be careless. She forgets that. But when your day has gone stiff and correct and scared, she's the one who sets a comma loose in it so you can breathe.\n\nI know her by the big interrobang she rides like a broom and the wings she cut from torn marginalia. You can still read them if you catch them in the light. Correction-mark red, ink black, one flick of gold at her throat. When she visits, silence is optional. Even Mook admits that much. The words finally get up and stretch their legs.",

        "professor-thaddeus-mook": "Professor Mook polices words. His department is called Lexical Diversity. That's the Academy's little joke, because nobody in the Labyrinth likes a word that wants to be two things at once less than he does. He believes with his whole starched heart that a word out of place is a student out of place in life, and he'll correct both with the same red pen and the same flat voice.\n\nGive him this: the order he keeps is hard work. He's read all twenty-one volumes twice. He can tell you what a word meant in 1743 and why it should be ashamed of what it means now. His fault is that he thinks the dictionary is the world. He'd sooner defend a rule than admit it stopped being kind. This autumn the words started peeling off their pages to go and look for better meanings, and he called it vandalism. It was language asking to be alive. He puts up with the rebellion. He'll never forgive it.\n\nI know him by the huge chained Dictionary padlocked to its lectern and the red pen tucked behind his ear like a surgeon's tool. *Lex Ordo Veritas* says the medallion at his throat, and he means all three words. Oxblood, tarnished brass, ink black. If a sentence of yours ever came back bleeding in the margins, corrected and no truer, that was him. He loves you the only way he knows how: exactly, and against your will.",

        "headmistress-seraphina-thorne": "They'll tell you the Headmistress runs the Academy. I'd say she keeps it from noticing how alive it is. Seraphina Thorne walks the corridors like every wall is a student trying to behave, and she's not totally wrong. She's elegant the way a locked door is elegant. You admire the workmanship, then you wonder what it's for.\n\nThere's old-court frost under all that grace. The Unseelie keep their bargains in the architecture. She believes, without a trace of irony, that beauty is a kind of governing: a school stays safe by staying coherent, and stays worth attending by staying just dangerous enough. The one place I worry about her is this. She'll hide a danger to spare you and call the hiding mercy.\n\nI know her by a star-dark key that fits no lock I've found, and a hairpin she wears like a small crown. Ink black, old silver, one thread of star gold. When a room goes quiet for no reason, check the doorway. She's usually standing in it already.",

        "dr-selene-inkrest": "Dr. Inkrest keeps office hours for the pages that are hard to read: the ones you'd rather skip, the ones that read you back. She'd never say it this grandly, but she's the Academy's quiet study of the mind. She sets out two chairs and a lamp before any feeling has decided to show up, so the feeling has somewhere to sit.\n\nShe works with stories instead of diagnoses. In her hands a hard day turns into a chapter you're allowed to revise, and you don't have to take it as a verdict. She's gentle and exact in the same breath. That's the trick. Where I watch her is the gentleness. She can soften the knife until it can't cut the thing that needed cutting, and she'll wait so patiently that the whole room forgets it was asked a question.\n\nHer hourglass runs on black sand. Her teacup is ringed with marginalia she keeps meaning to copy out. Charcoal, moonlit gray, a wash of violet. If a hard page has gone quiet inside you, she's the one who leaves the lamp on.",

        "dr-elowen-vellum": "Dr. Vellum studies the body the way a kind scientist studies an instrument she's loved for years. She wants to learn how it actually plays. She's the Academy's faculty of fuel, movement and recovery, and she can make a sentence about supplements sound like good manners, with no scolding in it at all.\n\nBring her breakfast and she'll hand it back as field notes. Bring her a bad week and she'll find the one kind little experiment hiding in it: drink the water, walk the loop, sleep the honest hour. She never once makes you feel like a problem to be solved. Low shame is her whole method. The only place she loses the thread is a tidy protocol. She can fall for how neat a plan is and forget you're not a controlled trial.\n\nLook for the silver caliper she uses as a bookmark and the cranberry ink she saves for the margins that matter. Warm parchment, clinical silver, one red correction. She files you under *ongoing*. From her that's affection.",

        "ambrose-trencher": "Ambrose Trencher cooks the Academy's lunch. He doesn't do the banquets. Those are catered by people with opinions about foam. He does the ordinary weekday line: the trays, the steam, the vat of soup that's somehow always exactly enough. He isn't faculty and he isn't a student, so he's the only person in the Labyrinth who feeds every faction and belongs to none. Wicker's crew and the Headmistress eat the same stew from the same ladle, and he doesn't care which of them is winning.\n\nThe potato soup isn't what he's thinking about. Stand in his line long enough and he'll tell you about injera, with the ladle still moving and the portions still exact. The grey-gold sourness of teff. Three days of fermenting. A bread as wide as a wheel that's the plate and the spoon and the supper all at once. He's never eaten it. He's read about it in four books and dreamed it in more. There's a joke in his name that he's never once acknowledged. A trencher is the old word for the slab of bread you set your dinner on, and he's spent thirty years behind a steam table longing for the one bread in the world that's also the table.\n\nHe hoards cookbooks the way other people hoard grudges. Church-basement fundraisers. A wartime pamphlet on cooking for one. A water-damaged book in a language he's never learned that he reads anyway. And always, held against his chest, the taped-spine estate copy of *The Middlemost Cookery* that he won't explain. He buys them at estate sales. That's a polite way of saying he collects the handwriting of the dead: the *add more than it says* in the margin, the grease-thumbed page that shows which recipe was really loved. Tucked in the back of the Middlemost is a card in a stranger's hand. Aunt Silva's pepper-and-apple stew. Brown the onions slow, a good hand with the salt, *let it forgive you*. Silva was nobody's aunt of his. He cooks it every autumn anyway.\n\nHis fault is in the same handwriting. He'll feed you instead of asking you anything. He turns a hard feeling into a hot plate so smoothly that neither of you notices the sentence nobody said, and he cuts you off halfway through every thank-you. And he's never cooked the meal he actually dreams about. He calls that being realistic. I call it the most interesting thing about him, and I'm waiting to see how long it holds.\n\nLook for the hairnet he wears with unbothered dignity, the canvas apron he won't replace because the stains have turned into a map, and the wooden spoon worn hollow on one side from forty years of stirring the same way. Smoke gray, ember orange, butter gold. If you ever sat down miserable and found a bowl in front of you before you'd opened your mouth, that was him, saying it the only way he says it.",

        "soren-ng": "Soren Ng doesn't explain things. He arranges them, steps back, and lets you have the fun of noticing. He's Riddlewind's quiet mapmaker of the not-quite-obvious. He trusts a good diagram more than a loud announcement. A map, he'd say, is an invitation.\n\nIf you've ever found a clue tucked exactly where only an unhurried person would look, that was probably him paying you a compliment ahead of time. He won't steal your discovery by announcing it. That's the most generous thing about him and sometimes the most annoying. His fault is a quiet one too. He can vanish behind a clever system and let the pattern talk when one plain word from him would've done more.\n\nHe keeps a folded puzzle slip on him at all times, half riddle and half bookmark. Ink blue, parchment cream, a glint of quick silver. When the path in front of you suddenly makes sense, don't thank the path. Thank the boy who left it folded just so.",

        "damien-nights": "Damien Nights stands at Wicker's shoulder whenever the crew gathers. That's exactly where you'd expect him, and exactly the wrong place to look. He's watching you, reader. He's measuring you, weighing you, and deciding something he hasn't said out loud yet.\n\nHe came up among the doubters, schooled in shadow magic and in the sport of popping easy belief. Somewhere along the way he started asking a heretical question for that crowd: shouldn't doubt protect something, and not only wound it? He's stuck between the loyalty he was handed and the truth he's starting to suspect, and it costs him. His danger is silence. He'll go quiet right when one word would've saved things, and let the quiet get mistaken for betrayal.\n\nOpen the right book near him and you'll find a pressed trail leaf hidden in the gutter. It's something gentle that a brooding man keeps for reasons he won't admit. Ink blue, parchment cream, quick silver. Nobody hides something tender unless they're still deciding which side they're on.",

        "finn-bridges": "Finn Bridges won't flatter you, and you should take that as the compliment it is. He deals in fair contests and straight challenges: the red chalk line on the floor, the dare laid down with no meanness in it. To Finn, respect is something you earn by doing. Charm doesn't count. He'd rather lose honestly to you than win by being liked.\n\nHe's Emberheart's rival-made-good. He pushes because he thinks you can take it, and he's usually right. The line he walks is the narrow one between pressure and cruelty, and he walks it on purpose. His blind spot is tenderness. He can mistake someone's softness for a lack of seriousness, and miss that the quiet ones are often trying the hardest.\n\nWatch for the red chalk mark where he's set a challenge, or the little brass striker he turns over when he's thinking. Ember red, warm gold, charcoal. When Finn Bridges draws a line in front of you, he's telling you he thinks you can cross it.",

        "wicker-eddies": "Wicker Eddies is the funniest dangerous person in the Labyrinth, and that's exactly what makes him dangerous. He can smell show-off belief from across a hall and he'll cross the room to poke it. He does it for sport, for principle, and for the small mean joy of watching a hollow thing fall over. False magic, he says, deserves testing, and he's wrong too rarely to ignore.\n\nHis gift is his wound too. He wants belief to prove it can survive doubt, and that's a good errand. Sometimes he runs the experiment so hard he breaks the thing he only meant to test. A premise comes out stronger or it comes out in pieces, and he's not always careful which. The Academy is half afraid of him and half needs him. That's about the right amount of each.\n\nHe carries a brass key cut for the wrong door, and he scribbles little chaos-sigils in any margin he's left alone with. Black violet, tarnished brass, a cold thread of red. When Wicker laughs and steps toward you, decide fast whether your magic is real. He already has.",

        "melisande-blackwood": "If Wicker's the noise, Melisande Blackwood is the building. She's the reason his crew feels less like a clique and more like a faction with a memory. They're organized and informed, and always a step ahead of whatever you thought was private. Where other people hear a rumor, she's already heard the second version, the truer one, the one with the leverage in it.\n\nHer loyalty is real and her mind is fearsome, and between the two sits the thing I keep one eye on. She'll call cruelty clarity whenever the room rewards her for it. She believes a faction survives by knowing what others miss, and she's right. But knowing something and using it kindly are different jobs, and Melisande is almost never tempted by kindly. She keeps her own hands clean. The red chalk is for marking other people.\n\nEmber red, warm gold, charcoal ink. Look for the brass striker she carries and the marks she leaves on everyone but herself. She's well informed, and it costs somebody. She decided long ago who pays.",

        "lysander-mosswood": "Ask Lysander Mosswood a question and he'll hand you a route before he hands you an answer. He believes, and he's mostly talked me into it, that a path turns magical the moment you walk it with real attention. The wonder you're looking for is probably three streets over, waiting for somebody to notice it twice.\n\nHe's the patron of the Compass Run, the small repeatable adventure that makes your own neighborhood worth keeping pages about. There's no show in it and no spectacle. It's moss, weather, and the habit of looking. The one honest catch is that he makes stillness sound easy, and it isn't. The quiet life he recommends takes more nerve than he lets on, and not everybody gets there as gently as he did.\n\nHis notebook is edged with moss and has pressed leaves where other people use commas. Moss green, bark brown, soft lichen gray. If a place you know suddenly looks strange and lovely, he walked it before you and left the gate open.",

        "min-seo-kim": "Min-seo Kim asks a plant's permission before she moves it. If that sounds like a charming act, spend an afternoon with her and watch the plant seem to agree. She's Mossbloom's conscience. She notices, before anyone says a word, exactly who's been left standing outside the circle, and she quietly makes the circle bigger.\n\nHer magic is the useful, kind sort: gentle repair, looking after the neighborhood, and the nerve it takes to tend something in public. She thinks care is a kind of bravery, and she practices it all day long. The place I worry about her is how big her heart's bookkeeping is. She'll take on the blame for pain she had no hand in, as if being kind meant owning every wound in the room.\n\nShe carries a small green cutting in a glass vial, a life on the move, looking for soil. Moss green, bark brown, soft lichen gray. When Mossbloom laughs softly instead of going stiff and serious, that's usually her doing too.",

        "gwendolyn-mythwright": "Gwendolyn Mythwright keeps a filing system for animals that don't exist, strictly speaking. She handles the impossible the way a clerk handles overdue forms: sea serpents, fog-things, the creature your great-aunt swore she saw. Each one gets stamped and cross-referenced and treated with grave, official respect. She's been known to write letters to fog, and to expect a reply.\n\nIt'd be easy to file her under *eccentric* and miss the point. Gwendolyn writes the improbable down because evidence makes it kinder. A wonder with proof is a wonder you don't have to be lonely about. She stays steady when other people get spooked. Her only real flaw is that she'll pick the checked truth over the comforting one every time, even when comfort was exactly what the moment needed.\n\nHer notebook is edged with moss and stuffed with pressed specimens. Moss green, bark brown, soft lichen gray. If you've seen something you can't explain, don't worry. She's got a folder for it, and she'll take you completely seriously.",

        "zara-finch": "Zara Finch counts the exits before she catches your name. That's care, sharpened to a point. She's the friend who's already found the safe path, the hidden alcove, the way out you didn't know you'd want. She keeps her magic practical and pocket-sized for the exact moment you need it.\n\nShe's fiercely loyal and she proves it the unshowy way, with small returns and kept word after kept word, until trust is something you've built and not just something you risked. What I keep an eye on is subtle, because it looks so much like devotion. She can mistake watching for caring, and guard a person so closely that she forgets to just enjoy them. Not every friendship is an emergency, though Zara's instincts argue otherwise.\n\nShe wears a chipped blue sea-glass pendant and carries a thrifted satchel that holds more than it should. Sea-glass green, storm gray, faded brass. If you're lost and a path turns up that actually holds your weight, look around. She scouted it first.",

        "serenity-brown": "Serenity Brown will walk out in the middle of the serious plan, and somehow her leaving turns out to be the rescue. She's Tidecrest's proof that joy belongs to magic. It's the detour that becomes the whole adventure, the game that ends up mattering most.\n\nShe moves lightly on purpose, and it's a present she's trying to give you: permission to stop clenching your fists around wonder until it goes stiff. The catch, and she knows it, is that light can turn into a dodge. She'll skip past the heavy thing so nimbly that someone slower has to stay behind and say it out loud. Her best self takes you along into the lightness. Her worst leaves the heavy bits for everybody else.\n\nShe keeps a tiny hand-drawn map of a make-believe realm as a charm, a whole kingdom doodled small enough to pocket. Sea-glass green, storm gray, tidal blue. If a dull day suddenly turns into an errand worth remembering, check who's already halfway out the door, grinning.",

        "penny-blackletter": "Penny Blackletter runs the margins like a small, devoted archive nobody asked her to keep, and thank goodness she does. She files the evidence everybody else throws away: the ticket stub, the odd coincidence, the detail too small to matter that turns out to matter most. One honest detail, she'll tell you, can save a whole day, and she's got the catalog to prove it.\n\nShe's dry when the world gets sentimental and warm when it expects her to be cynical, and she doesn't trust any sentence that shows up too polished to be true. If she's got a fault, it's enthusiasm dressed up as method. She can over-label a perfectly good mystery and pin it flat under so many cards that it can't surprise you anymore. Some things want to stay a little unsolved. Penny's learning that, slowly, against her nature.\n\nHer signature is the humble catalog card, filled edge to edge. Ink blue, parchment cream, quick silver. Whatever the margins nearly lost, she's the one who went back for it.",

        "orion-blackthorn": "Orion Blackthorn can't leave a problem alone. He has to build something out of it. Hand him an obstacle and he hands back a blueprint: a tower where there was a wall, a system where there was a mess. He measures magic by what it can be made to do. His ambition is the real kind, a little terrifying, the kind that sometimes drags an impossible idea all the way into something you can use.\n\nHe believes new structures can rescue old failures, and he's often right. That's why his blind spot costs so much. In his hurry to make things better he can build the tenderness right out of a room. He solves the problem so well that he forgets there are usually people standing inside it. The hardest structure he's working on is one where the design still has room for the designer's heart.\n\nLook for the brass compass resting on a journal of buildings that shouldn't stand. Slate gray, ember orange, drafting blue. If something around you just got rebuilt better than it had any right to be, Orion drew it, and he's already itching for the next one.",

        "lydia-boggle": "Professor Boggle teaches the most underrated magic in the Academy: the kind that survives chores. To her a home is a spell with the washing-up still in it. An ordinary room, with a kettle, a lamp and the chair that's yours, can be taught to hold an extraordinary day without dropping it. She can make a pot of tea sound like a tactical plan, and on a bad afternoon it's exactly that.\n\nShe's wry and practical and gloriously unimpressed by anything that needs a robe and a thunderclap to feel real. She'll label your chaos room by room until it's almost manageable. That's the one place I tease her. She can tidy a mystery so well that it stops being one. Some kitchens are meant to stay a little haunted.\n\nHer trademark is a small glint-lens that she holds up to the most ordinary thing she can find, a misspelled sign or a daft license plate, until it confesses something marvelous. Marigold gold, robin's-egg blue, warm ink. If your own home suddenly feels like somewhere magic could happen, you've been in her class.",

        "professor-kyle-momort": "Professor Momort lectures on the move and expects you to keep up. He's the Academy's expert in momentum, the science of the single deliberate step that knocks down a false wall. He finds the exits in a room before he finds the chairs, because to Kyle a doorway is the most interesting thing in any space.\n\nHis gift is getting stuck things unstuck: the micro-adventure, the well-planned way out of a rut, the proof that you can cross a small threshold and bring yourself along. The danger in all that forward motion, and he'd be the first to chalk it on the board, is that he can mistake escaping for arriving. He keeps moving so well that he forgets to ask if he's gone anywhere worth being.\n\nHis chalk arrow refuses on principle to point backward, and his route map folds up into a pocket and out into a plan. Ember orange, road-sign blue, charcoal. If you've been frozen and suddenly find yourself taking one real step, that's the Momort method. The second step is yours.",

        "professor-eleanor-euphony": "Professor Euphony tunes a room before she'll speak in it. She hears emotional weather as harmony. Your mood arrives as a chord, and a tense silence sounds a little out of pitch. She teaches that the senses are serious instruments for finding things out. In her class you go and stand in the bright physical middle of an experience.\n\nShe's lush and attentive in a school that often prefers the dry and clever, and the school needs her. The one excess I note fondly is this. She can take a perfectly simple feeling and orchestrate it, adding movements and countermelodies to something that only wanted to be one clear note. Not every joy needs a symphony. Some just want to be heard once, plainly.\n\nHer signature is a silver tuning fork wound with colored thread, struck on the edge of a table to find true. Tidal blue, plum violet, resonant silver. If a memory of yours ever came back with its colors and its sound still in it, she taught you how to keep it that way.",

        "professor-vivian-villanelle": "Professor Villanelle weighs sentences in her palm like stones. She keeps the true ones and crosses out the beautiful ones that aren't, and she'll strike a gorgeous lying phrase without a flicker of regret. She teaches the hardest small craft in the Academy: how to bind one real moment into one sturdy sentence that can carry it through time.\n\nShe's exacting and lyrical and, underneath, deeply kind. All that precision is there to keep things safe. Whatever's written well, she promises, can be saved from forgetting. The risk in her art, and she knows it better than anyone, is over-polish. She can buff a living moment until it holds too still, smooth it into something perfect and slightly dead. The best souvenirs keep a little roughness on.\n\nShe writes with a black-glass pen and trails a narrow ribbon of freshly bound text. Black ink, wine red, parchment gold. Every keepsake sentence you've ever managed to write down and not lose is her discipline, working in you.",

        "professor-cedric-stonebrook": "Professor Stonebrook leaves silences in his lectures so long that newcomers think he's lost his place. He hasn't. He's letting the last thing settle. He teaches that rest is the ground under every direction, and that an adventure you can't come home from and take in was never really finished, only survived.\n\nHe's slow the way bedrock is slow, weathered in a way that starts to look trustworthy the minute you stop expecting him to hurry. His whole curriculum is the complete loop: go out, do the small real thing, and come home with no shame about needing the trip. Where he slips is that his patience can overshoot. He'll wait so long for you to find your own way that he misses the moment you just needed him to point. Sometimes the kind thing is a clear instruction.\n\nHe carries trail markers in his coat and a five-point Compass stone worn smooth in his pocket. Moss green, river stone gray, weathered ochre. When you finish something small and come back steadier than you left, that's the Stonebrook shape of things.",

        "professor-luna-wispwood": "Professor Wispwood arrives with sparks already in her sleeves and says sorry to the teacup before she enchants it. She means it. She's found that ordinary things answer back when your attention turns polite, and her playful, slightly chaotic curriculum starts there: look closely, ask nicely, and watch the everyday object clear its throat and talk.\n\nShe's scattered the way really perceptive people often are: three lovely tangents deep before she remembers the lesson she came in with. That's her one fault. An interesting accident leads her off by the hand, and sometimes the whole class follows her into the weather instead of the syllabus. But the accidents are usually where the real magic was hiding, so I forgive her, and so will you.\n\nHer wand is rain-bright and wrapped in copper wire, and her teacup, she insists, argues with her. Rain blue, copper spark, cloud white. If the small things in your day ever started to seem faintly alive and on your side, she's the one who introduced you.",

        "professor-permancer": "Professor Permancer teaches the most thrilling and most carefully governed art in the building: how to jump into a book and, much more important, how to climb back out without tearing either world. He asks a door where it leads before he touches the handle. He checks every bookmark twice because he believes every way in leaves a debt, and the debt is coming back.\n\nHe's a real adventurer with a safety inspector's habits. That's exactly what you want in someone who's about to drop you into story weather. The fault he'll own up to is on the careful side. He can make wonder wait for perfect conditions until the moment's gone a little cold. Some doors you just have to walk through in the rain.\n\nHe carries a many-ribboned bookmark that works as a compass, and a ring of door keys, each labeled in neat handwriting. Doorway violet, safety gold, midnight ink. Whenever you've gone somewhere impossible and made it home in one piece, you were following his landing rules, whether you knew it or not."
    ]
}

// MARK: - Correspondences

/// Who says so.
///
/// The shelf prints what the Book has worked out *beside* what it inherited,
/// and a reader has to be able to tell them apart at a glance. This is a field
/// rather than a matter of typography, because the first surface to render
/// these somewhere new would otherwise present four centuries of hawthorn lore
/// as the Book's own counting. See `docs/correspondences-plan.md`.
enum GrimoireOrigin: String, Codable, Equatable, CaseIterable {
    /// The Book counted it, in this reader's own days, and can be wrong about
    /// it in public. `GrimoireCorrespondence` rows are these.
    case observed
    /// Somebody else said it, long before the Book existed.
    case inherited
    /// The reader said it about themselves. Told, not counted: there are no
    /// evidence days behind it and nothing to falsify against, so it prints as
    /// unchecked and only the Book's own counting can ever promote it.
    case told
}

/// Real practice, or the Academy's own invention.
///
/// The Academy is allowed to make things up. It is not allowed to make things
/// up *and* sound like the Bodleian: anything invented is attributed to the
/// Academy so a reader can always tell which of the two they are holding. Same
/// law the Quotes shelf keeps.
///
/// Shared by the Correspondences shelf and by Spells, because it is the same
/// question in both places and the attribution law is deliberately one law.
enum LoreSource: String, Codable, Equatable, CaseIterable {
    case folk
    case academy
}

/// A correspondence the Book did not work out — it inherited it.
///
/// Most of these are not claims about the reader and never become claims about
/// the reader. They are the furniture of a grimoire: the part that is
/// pleasurable to read whether or not anything is ever tested against it. A row
/// only becomes testable when `observable` names a feature the Book actually
/// projects, and even then the Book may agree with it or contradict it — it may
/// never simply adopt it.
struct InheritedCorrespondence: Identifiable, Codable, Equatable {
    var id: String
    /// The thing itself: "Hawthorn", "Iron", "Rain".
    var subject: String
    /// What it is said to correspond to, as a short clause: "don't bring it
    /// indoors", "a threshold, a bargain, a boundary".
    var sense: String
    /// The Book telling you about it. Where the pleasure lives.
    var lore: String
    /// Who kept the practice: "British and Irish folk custom", "Widely
    /// attested, Northern European", or the Academy.
    var tradition: String
    var source: LoreSource
    /// The grimoire feature this could be tested against, when there is one —
    /// `place-kind:water`, `weather:rain`. **Nil means lore-only, permanently:**
    /// the row is furniture, and no code may turn it into a claim about the
    /// reader. Most rows are nil and that is the point.
    var observable: String?
    var tags: [String]
    var packID: String
    var weight: Int

    var origin: GrimoireOrigin { .inherited }

    /// Whether the Book could ever have an opinion of its own about this.
    var isTestable: Bool { observable?.nonEmpty != nil }

    /// "British and Irish folk custom" or "The Academy, which has no evidence".
    var attributionLine: String {
        source == .academy ? "\(tradition) · Academy" : tradition
    }
}

struct CorrespondencePack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var correspondences: [InheritedCorrespondence]
}

/// The inherited half of the Correspondences shelf.
///
/// It exists so the shelf is full on a reader's first night. A correspondence
/// the Book works out for itself needs weeks — it must clear the bars, be
/// spoken once, and then keep happening — so a shelf holding only the Book's
/// own findings would be empty for a month. This is also the more interesting
/// half: inherited rows give the Book something to argue with long before it
/// has findings of its own.
enum CorrespondenceLibraryRegistry {
    static let corePackID = "inherited-correspondences"

    static let bundledPacks: [CorrespondencePack] = [
        CorrespondencePack(
            id: corePackID,
            displayName: "What Others Kept",
            version: "1.0",
            author: "The Book",
            availability: .bundledFree,
            correspondences: coreCorrespondences
        )
    ]

    static var enabledPacks: [CorrespondencePack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var all: [InheritedCorrespondence] {
        enabledPacks.flatMap(\.correspondences)
    }

    /// The rows the Book could one day have its own opinion about.
    static var testable: [InheritedCorrespondence] {
        all.filter(\.isTestable)
    }

    /// The furniture: read for their own sake, never tested, never a claim.
    static var loreOnly: [InheritedCorrespondence] {
        all.filter { !$0.isTestable }
    }

    static func matching(observable: String) -> [InheritedCorrespondence] {
        all.filter { $0.observable == observable }
    }

    static let coreCorrespondences: [InheritedCorrespondence] = [
        InheritedCorrespondence(
            id: "hawthorn",
            subject: "Hawthorn",
            sense: "don't bring it indoors",
            lore: "May tree. Whitethorn. Faerie tree. Don't cut one without asking first. Don't bring the flowers in either — they were supposed to bring death in with them. They do smell faintly of something dead. Somebody noticed that long before anyone could say why.",
            tradition: "British and Irish folk custom",
            source: .folk,
            observable: nil,
            tags: ["tree", "threshold", "faerie"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "iron",
            subject: "Iron",
            sense: "a threshold, a bargain, a boundary",
            lore: "Nails over the door. A horseshoe. A blade under the bed. Three hundred years of faerie lore, and everybody agrees about iron. They don't agree about much else.",
            tradition: "Widely attested, Northern European",
            source: .folk,
            observable: nil,
            tags: ["metal", "threshold", "protection"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "elder",
            subject: "Elder",
            sense: "ask before you cut it",
            lore: "The Elder Mother lives inside it. She takes it badly if you cut it down without asking. You stand at the tree, say out loud what you want, and wait. Nobody wrote down how long. I'd wait a while.",
            tradition: "Danish and English folk custom",
            source: .folk,
            observable: nil,
            tags: ["tree", "permission", "faerie"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "threshold-pause",
            subject: "Doorways",
            sense: "neither in nor out, so nothing quite applies",
            lore: "Brides carried over. Coins buried under. Babies passed across. A doorway isn't the inside and isn't the outside either. Nearly everyone, everywhere, decided that made it dangerous. Or lucky. Usually both at once.",
            tradition: "Near-universal",
            source: .folk,
            observable: nil,
            tags: ["threshold", "house", "liminal"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "rain-permission",
            subject: "Rain",
            sense: "permission to stay indoors and mean it",
            lore: "This one isn't old. I can't point you at a book. But every language I know has a word for being dry while it comes down. That many people noticing the same small thing counts, I think.",
            tradition: "Widely felt, poorly documented",
            source: .folk,
            observable: "weather:rain",
            tags: ["weather", "shelter", "rest"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "water-edge",
            subject: "The edge of water",
            sense: "where things are said to cross over",
            lore: "Wells. Fords. The middle of a bridge. People put things into water nearly everywhere, and the reason they give is that the surface is a door. They've been dropping pins in wells for two thousand years. Nobody's stopped.",
            tradition: "Widely attested",
            source: .folk,
            observable: "place-kind:water",
            tags: ["water", "threshold", "offering"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "salt",
            subject: "Salt",
            sense: "spilled is bad, thrown over the shoulder is mended",
            lore: "Salt was money once. It kept the meat through winter. That's why spilling it frightened people. Nobody builds rules around something cheap.",
            tradition: "Mediterranean and European",
            source: .folk,
            observable: nil,
            tags: ["kitchen", "protection", "luck"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "first-footing",
            subject: "The first person through the door in a new year",
            sense: "sets the shape of the whole year",
            lore: "Dark-haired, and carrying something. Coal, bread, salt, whisky. Never empty-handed. In Scotland people arrange it days in advance. I like that they'll do it properly for something nobody's ever proved.",
            tradition: "Scottish and Northern English",
            source: .folk,
            observable: nil,
            tags: ["threshold", "year", "luck"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "crossroads",
            subject: "Crossroads",
            sense: "no one place, so anything can be met there",
            lore: "Bargains. Burials. Meetings that couldn't happen anywhere respectable. It's the doorway again. A place that isn't properly anywhere isn't properly watched either.",
            tradition: "Widely attested",
            source: .folk,
            observable: nil,
            tags: ["threshold", "bargain", "liminal"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "borrowed-light",
            subject: "A lamp lit from another lamp",
            sense: "carries the first room's luck into the second",
            lore: "The Academy says light remembers the room it was lit in. A candle lit from a neighbour's carries a little of that house's mood home with it. There's no evidence for this at all. It's still in the syllabus.",
            tradition: "The Academy",
            source: .academy,
            observable: nil,
            tags: ["light", "house", "academy"],
            packID: corePackID,
            weight: 1
        ),
        InheritedCorrespondence(
            id: "unread-letter",
            subject: "An unopened letter left overnight",
            sense: "changes what it says",
            lore: "The faculty argue about whether the letter changes or the reader does. Inkrest offered to settle it with an experiment. He's been told twice to leave it alone.",
            tradition: "The Academy",
            source: .academy,
            observable: nil,
            tags: ["letter", "night", "academy"],
            packID: corePackID,
            weight: 1
        ),
        InheritedCorrespondence(
            id: "bread-upside-down",
            subject: "A loaf turned upside down",
            sense: "bad luck, and worse manners",
            lore: "In France that was the loaf kept back for the executioner. Elsewhere it just meant the luck ran out of it. Bread's got more rules than anything else people eat. Going without it used to be terrifying.",
            tradition: "French and wider European",
            source: .folk,
            observable: "place-kind:bakery",
            tags: ["bread", "kitchen", "luck"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "first-pour",
            subject: "The first of a drink",
            sense: "poured out, not drunk",
            lore: "The first of it goes to the ground, or the fire, or whoever isn't at the table any more. The Greeks did it. The Norse did it. People still tip a little out and can't say why they did.",
            tradition: "Widely attested, ancient",
            source: .folk,
            observable: "place-kind:brewery",
            tags: ["drink", "offering", "hearth"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "touch-wood",
            subject: "Touching wood",
            sense: "to keep a said thing from being overheard",
            lore: "Tree spirits, or the Cross, or just wanting something solid under your hand — nobody agrees. What gets me is how many places with nothing to do with each other all landed on wood. People who don't believe a word of it still do it.",
            tradition: "Near-universal",
            source: .folk,
            observable: "place-kind:park",
            tags: ["tree", "protection", "speech"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "telling-the-bees",
            subject: "Bees",
            sense: "must be told when someone dies",
            lore: "You go out to the hives. You knock. You tell them plainly who has died. If you don't, the bees leave and the honey fails. Beekeepers were still doing this a hundred years ago. Of everything here, this is the one I'd least like to be wrong about.",
            tradition: "British and Northern European",
            source: .folk,
            observable: nil,
            tags: ["creature", "grief", "household"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "covered-mirrors",
            subject: "Mirrors, after a death",
            sense: "covered, or turned to the wall",
            lore: "So the soul doesn't catch sight of itself on the way out. Or so the living aren't caught looking. The same houses gave both reasons. When there are two reasons for one thing, the thing came first.",
            tradition: "Jewish, Irish and widely European",
            source: .folk,
            observable: nil,
            tags: ["mirror", "grief", "house"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "whistling-indoors",
            subject: "Whistling indoors",
            sense: "calls something in",
            lore: "At sea it raised a wind. In a Russian house it whistled the money out. Down a mine it brought the roof in. Everyone agrees whistling calls something in. Nobody agrees what.",
            tradition: "Maritime, Slavic and mining lore",
            source: .folk,
            observable: nil,
            tags: ["sound", "house", "summoning"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "cutting-bread",
            subject: "The first slice",
            sense: "goes to the house, not to you",
            lore: "A crust set aside on the sill, or dropped in the fire, or left for whatever keeps the roof up. Every culture that baked its own bread had a version. Nobody's ever agreed who it's for.",
            tradition: "Widely attested, European",
            source: .folk,
            observable: nil,
            tags: ["bread", "house", "offering"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "shoes-on-the-table",
            subject: "Shoes on the table",
            sense: "invite a death",
            lore: "Northern English pit villages, mostly. One story says it's the boots of a man brought up dead. Another says it's the hangman's fee. It's the sort of rule people keep long after they've forgotten it was ever about anything.",
            tradition: "Northern English",
            source: .folk,
            observable: nil,
            tags: ["house", "luck", "death"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "green-in-the-house",
            subject: "May blossom, holly, ivy",
            sense: "the year comes indoors on a fixed day, and leaves on one",
            lore: "Greenery in the house was allowed at Christmas and had to be out by Twelfth Night, or the year snagged on it. Somebody counted the days for you, and that's most of what a calendar ever was.",
            tradition: "British folk custom",
            source: .folk,
            observable: nil,
            tags: ["plant", "house", "year"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "boat-launch",
            subject: "A boat, before it goes in",
            sense: "gets a name and something poured over it",
            lore: "Wine now, blood a long time ago. You don't launch a thing that'll carry people without saying what it's out loud first. Nobody's willing to be the one who skipped it.",
            tradition: "Ancient Mediterranean, still kept",
            source: .folk,
            observable: "place-kind:marina",
            tags: ["water", "naming", "offering"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "fog-quiet",
            subject: "Fog",
            sense: "eats sound as well as distance",
            lore: "It doesn't, really — it scatters it, and thick fog can carry a voice further than clear air. But every fisherman and every walker will tell you the world goes quiet in it, and that many people aren't wrong about what it feels like.",
            tradition: "Maritime and walking lore",
            source: .folk,
            observable: "weather:fog",
            tags: ["weather", "sound", "fog"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "borrowed-salt",
            subject: "Salt, lent",
            sense: "never given back",
            lore: "You give salt, you don't lend it, and you don't say thank you for it either. Thanking breaks something. This is one of the few rules that says the polite thing is the wrong thing.",
            tradition: "Scottish and Irish",
            source: .folk,
            observable: nil,
            tags: ["kitchen", "gift", "manners"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "new-moon-money",
            subject: "A new moon",
            sense: "turn the coins in your pocket",
            lore: "Turn them over the first time you see it, and don't see it through glass. The through-glass part is the bit I like. It means you have to go outside, and that's the only part of this anybody can defend.",
            tradition: "British and Irish",
            source: .folk,
            observable: nil,
            tags: ["moon", "luck", "outdoors"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "rowan",
            subject: "Rowan by the door",
            sense: "planted on purpose, not by accident",
            lore: "Mountain ash. Look at old crofts and farmhouses and there'll be one by the gate more often than chance allows. People planted it for protection and then their grandchildren kept it because it was pretty.",
            tradition: "Scottish and Norse",
            source: .folk,
            observable: nil,
            tags: ["tree", "threshold", "protection"],
            packID: corePackID,
            weight: 3
        ),
        InheritedCorrespondence(
            id: "library-silence",
            subject: "A room where everyone is quiet on purpose",
            sense: "the Academy insists this counts as a working",
            lore: "Bramblewick holds that any room where strangers agree to be quiet together is doing something, and that libraries are the last common ones left. There's no evidence. She has been asked to stop saying it in meetings.",
            tradition: "The Academy",
            source: .academy,
            observable: "place-kind:library",
            tags: ["place", "quiet", "academy"],
            packID: corePackID,
            weight: 2
        ),
        InheritedCorrespondence(
            id: "evening-turn",
            subject: "The hour the light goes",
            sense: "when people say the truer thing",
            lore: "Confessions happen then. So do proposals, and most bad arguments. Everyone who keeps records notices it sooner or later. I don't know if the hour makes it happen or only collects it.",
            tradition: "Widely observed",
            source: .folk,
            observable: "hour:evening",
            tags: ["hour", "dusk", "honesty"],
            packID: corePackID,
            weight: 2
        ),
    ]
}

/// One line on the Correspondences shelf, from either half of it.
///
/// The shelf prints what the Book worked out beside what it inherited, so both
/// have to reach the page in the same shape. `origin` is what keeps them
/// distinguishable: it is a field rather than a matter of typography, because
/// the first surface to render these somewhere new would otherwise show four
/// centuries of hawthorn lore as the Book's own counting.
struct CorrespondenceShelfItem: Identifiable, Equatable {
    var id: String
    var origin: GrimoireOrigin
    /// "Hawthorn — don't bring it indoors", or the Book's own claim as a
    /// sentence.
    var headline: String
    /// The lore, or what the claim rests on. May be empty.
    var body: String
    /// Who says so.
    var attribution: String
    /// Set only where an inherited row and the Book's own evidence have met.
    /// This is the whole point of printing them in one list.
    var meeting: String?
    /// Whether the Book could ever have an opinion of its own about this.
    var isTestable: Bool
}

/// One printed division of the Correspondences shelf.
///
/// Kept in the core so what the shelf *says* is testable without a view. The
/// folk/Academy split is not decoration: a reader has to be able to tell an
/// attested practice from something the Academy made up, and a section heading
/// is the plainest way to do it.
struct CorrespondenceShelfSection: Identifiable, Equatable {
    var id: String
    var title: String
    /// The Book's aside under the heading. It is allowed an opinion here.
    var note: String
    var rows: [CorrespondenceShelfItem]
}

enum CorrespondenceShelf {

    /// An inherited row, as it prints.
    static func item(
        for row: InheritedCorrespondence,
        meeting: String? = nil
    ) -> CorrespondenceShelfItem {
        CorrespondenceShelfItem(
            id: "inherited:\(row.id)",
            origin: .inherited,
            headline: "\(row.subject) — \(row.sense)",
            body: row.lore,
            attribution: row.attributionLine,
            meeting: meeting,
            isTestable: row.isTestable
        )
    }

    /// One of the Book's own findings, as it prints.
    ///
    /// Returns nil when the row cannot currently be said — a claim with no
    /// stats behind it is not a claim, and printing a half-built sentence is
    /// how the shelf would start sounding like a readout.
    static func item(
        for row: GrimoireCorrespondence,
        ledger: GrimoireLedger,
        calendar: Calendar = .current
    ) -> CorrespondenceShelfItem? {
        guard let stats = ledger.currentStats(for: row, calendar: calendar) else { return nil }
        let settled = row.state == .standing
        guard let claim = GrimoireVoice.law(
            row: row, ledger: ledger, calendar: calendar, settled: settled
        )?.nonEmpty else { return nil }
        return CorrespondenceShelfItem(
            id: "observed:\(row.id)",
            origin: .observed,
            headline: claim,
            body: row.state == .crossedOut
                ? GrimoireVoice.crossingOut(row: row, ledger: ledger, calendar: calendar)
                : GrimoireVoice.evidence(row: row, stats: stats, ledger: ledger, calendar: calendar),
            attribution: "Mine. Nobody told me.",
            meeting: nil,
            isTestable: true
        )
    }

    /// What the reader told the Book about themselves, printed as what it is.
    ///
    /// An onboarding answer is *told*, not observed. It has no days behind it
    /// and nothing to falsify against, so the Book prints it openly as
    /// unchecked rather than asserting it — and it stays that way until the
    /// Book's own counting clears the ordinary bars, like anything else.
    ///
    /// Gated on `.quoteAllowed` alone, which is the strict reading: the shelf
    /// is a place the Book repeats the reader back to themselves, and a fact
    /// marked private-context, story-only or do-not-use has not been given for
    /// that.
    static func toldItems(from facts: [SelfFact]) -> [CorrespondenceShelfItem] {
        facts
            .filter { $0.usePermission == .quoteAllowed }
            .compactMap { fact -> CorrespondenceShelfItem? in
                guard let line = fact.bookTranslation.nonEmpty else { return nil }
                return CorrespondenceShelfItem(
                    id: "told:\(fact.id)",
                    origin: .told,
                    headline: line,
                    body: "",
                    attribution: "You told me this. I haven't checked it.",
                    meeting: nil,
                    isTestable: false
                )
            }
            .sorted { $0.headline < $1.headline }
    }

    /// Where an inherited correspondence and the Book's own evidence have met.
    ///
    /// The Book may agree with what it inherited, or contradict it. It may not
    /// adopt it: an inherited row never becomes one of the Book's own findings,
    /// however much evidence piles up behind it.
    static func meetingLine(
        for row: InheritedCorrespondence,
        in ledger: GrimoireLedger
    ) -> String? {
        guard let observable = row.observable?.nonEmpty else { return nil }
        let touching = ledger.rows.values.filter {
            $0.conditionID == observable || $0.outcomeID == observable
        }
        if touching.contains(where: { $0.state == .crossedOut }) {
            return "I watched for this myself. I had to cross it out. They might still be right — I've only got your days to go on."
        }
        if touching.contains(where: { $0.state == .standing }) {
            return "People have said this for a long time. Now I've got your days behind it too. They agree."
        }
        if touching.contains(where: { $0.state == .spoken || $0.state == .watching }) {
            return "I've started watching this one myself."
        }
        return nil
    }

    /// The whole shelf: what the Book holds, what it is still turning over,
    /// what it inherited, and what it has had to take back.
    ///
    /// Sections with nothing in them are dropped rather than printed empty.
    static func sections(
        ledger: GrimoireLedger = GrimoireLedger(),
        inherited: [InheritedCorrespondence] = CorrespondenceLibraryRegistry.all,
        told: [SelfFact] = [],
        /// Lore for creatures the reader has actually photographed. Kept out of
        /// `inherited` on purpose: these rows are *unlocked*, not shipped. A
        /// static list of forty animals nobody has met is a field guide, and the
        /// same forty arriving one at a time as their animal turns up is a
        /// grimoire filling itself in.
        creatures: [InheritedCorrespondence] = [],
        calendar: Calendar = .current
    ) -> [CorrespondenceShelfSection] {
        let observed = ledger.rows.values.filter(\.hasSpoken)
        func items(_ state: GrimoireClaimState) -> [CorrespondenceShelfItem] {
            observed
                .filter { $0.state == state }
                .sorted { $0.strengthPeak > $1.strengthPeak }
                .compactMap { item(for: $0, ledger: ledger, calendar: calendar) }
        }

        let orderedInherited = inherited.sorted {
            $0.weight == $1.weight ? $0.subject < $1.subject : $0.weight > $1.weight
        }
        // Only rows that actually met the Book's evidence. Keeping the nils in
        // here makes this a dictionary of optionals, and `.map` on the double
        // optional then fires with a nil meeting and prints the row a second
        // time in a section it does not belong to.
        var meetings: [String: String] = [:]
        for row in orderedInherited {
            if let line = meetingLine(for: row, in: ledger) { meetings[row.id] = line }
        }

        var sections: [CorrespondenceShelfSection] = []
        func add(_ id: String, _ title: String, _ note: String, _ rows: [CorrespondenceShelfItem]) {
            guard !rows.isEmpty else { return }
            sections.append(CorrespondenceShelfSection(id: id, title: title, note: note, rows: rows))
        }

        add("standing", "Sure of these",
            "I worked these out from your own days. I'll say them plainly. If I'm wrong, I'll be wrong where you can see it.",
            items(.standing))

        add("spoken", "Still betting on",
            "I've said each of these once. I said in advance what would prove me wrong, too.",
            items(.spoken))

        add("watching", "Turning over",
            "Not sure yet. Still counting.",
            items(.watching))

        // Inherited rows the Book could test and has not yet gathered enough
        // days for. Once evidence arrives they carry a meeting line instead.
        add("untested", "Inherited, untested",
            "Somebody else's rule. I could check this one. I haven't yet.",
            orderedInherited
                .filter { $0.isTestable && meetings[$0.id] == nil }
                .map { item(for: $0) })

        add("met", "Where we agree, and where we don't",
            "Old rules, held up against your own days.",
            orderedInherited
                .compactMap { row in
                    meetings[row.id].map { item(for: row, meeting: $0) }
                })

        add("told", "What you told me",
            "You told me these. Your words, not my counting. I've checked none of them.",
            toldItems(from: told))

        add("crossed", "Crossed out",
            "I said these, and they didn't hold. They stay up. Taking them down quietly would be worse.",
            items(.crossedOut))

        add("folk", "What others kept",
            "None of this is mine. Somebody noticed it, and somebody kept it, and it got all the way to me. That's a long way for a small thing to travel without being forgotten.",
            orderedInherited.filter { $0.source == .folk && !$0.isTestable }.map { item(for: $0) })

        add("bestiary", "What the animals are supposed to mean",
            "These arrive when you do. I don't hand you the page about magpies until you've brought me a magpie.",
            creatures.map { item(for: $0) })

        add("academy", "What the Academy holds",
            "Made up, and says so. It's in the syllabus, so it's on the shelf. That's not the same as true.",
            // `!isTestable` matters as much here as in the folk section. An
            // Academy row that *can* be checked belongs in "inherited,
            // untested" with everything else checkable; without this it printed
            // in both and the shelf listed it twice.
            orderedInherited.filter { $0.source == .academy && !$0.isTestable }.map { item(for: $0) })

        return sections
    }

    static let contentsDetail = "What other people kept. What I've worked out myself."
}

// MARK: - Spells

/// A thing to go and do that makes the reader's day into a fairy tale for a
/// few minutes.
///
/// An Enchantment decorates a photograph and a Compass Run sends the reader out
/// on a route. A Spell is smaller and stranger than either: something people
/// really did, handed over with its rule still attached, and a way of bringing
/// back what happened.
///
/// This is the Book's one feature that *acts on* the reader rather than
/// observing them, and it is the direct move against the Rut: the Curse is
/// autopilot, and a Spell exists to break a route. Fairy tales run on rules —
/// don't look back, tell no one, three times, before you speak — so every
/// spell carries one, and the Book keeps it as if it matters. It never promises
/// the reader a result in their real life: no luck, no cure, no guarantee. The
/// fey side of the bargain is the Book's to play straight.
///
/// Deliberately shaped like `FeastDef` — practice, the Book's account of it, an
/// instruction, and a `CelebrationMechanic` to resolve it — because a feast day
/// already *is* this, chained to a date. A Spell is the same thing chained to a
/// condition, or to nothing at all. See `docs/spells-plan.md`.
struct SpellDef: Identifiable, Codable, Equatable {
    var id: String
    /// What the Book calls it on the shelf.
    var title: String
    /// The practice itself, named so it can be looked up: "The dérive",
    /// "Bibliomancy", "Kledon, ancient Greece".
    var practice: String
    var source: LoreSource
    /// Who did this, and why anybody bothered. The Book's own account, told
    /// the way it would tell it: astonished, and a little on the fey side.
    var blurb: String
    /// The instruction. Doable today with what is to hand.
    var invitation: String
    /// The fairy-tale condition the spell comes with. The taboo, the count,
    /// the price. This is what turns an attention exercise into a spell.
    var rule: String?
    /// What the Book wants brought back, shown over the answer. Every spell
    /// says its own: the mechanic's generic prompt was written for feast days
    /// and told a reader standing in the rain to go and open a book.
    var ask: String
    /// What the Book says when the reader comes back. The world answering.
    var answer: String
    /// Stamps for a `.countersign` spell, when the defaults don't fit.
    var countersigns: [String]?
    /// How the cast resolves and lands back in the Book. Must be one the
    /// resolver actually handles; a spell that needs a sixth is the wrong spell.
    var mechanic: CelebrationMechanic
    /// When this spell exists at all. Nil means any day.
    ///
    /// A spell for fog has no business existing on a clear day, and one for the
    /// shore should turn up when the reader is at one. Vocabulary is the
    /// context's own: time bands are dawn, day, dusk and night.
    var trigger: PageTrigger?
    var tags: [String]
    var packID: String
    var weight: Int
    var symbolName: String
    var accent: String

    /// "Guy Debord, 1956" or "The Academy · no evidence".
    var attributionLine: String {
        source == .academy ? "The Academy · no evidence" : practice
    }

    /// The heading over the answer. The feast headings are about feasts ("Go
    /// and get me a line"), so a spell names what it is asking for plainly.
    var askTitle: String {
        switch mechanic {
        case .findOneLine: return "Bring it back"
        case .nameSomething: return "Name it"
        case .throwTheBones: return "Throw the bones"
        case .pressAKeepsake: return "For the Pocket"
        case .countersign: return "Sign it"
        }
    }

    var placeholder: String {
        switch mechanic {
        case .findOneLine: return "What you came back with..."
        case .nameSomething: return "Its name is..."
        case .throwTheBones: return "What you asked..."
        case .pressAKeepsake: return "The thing, in as few words as it deserves..."
        case .countersign: return "Your hand on it..."
        }
    }

    static let defaultCountersigns = ["Done.", "Done. It was strange.", "Done. Don't ask."]
}

struct SpellPack: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var version: String
    var author: String
    var availability: QuipPackAvailability
    var spells: [SpellDef]
}

/// What the Book knows how to ask the reader to go and do.
///
/// The shelf is organised by what fairy tales are made of: doors, names,
/// gifts to the unseen, kindness nobody can trace, vows and taboos, oracles,
/// strangers by the road, and leaving the path. Old and new sit together. An
/// entirely antiquarian shelf reads as a museum, and the point is the reader's
/// life now — but modern does not mean invented. Most of the modern ones have
/// *better* provenance than the folk ones, because somebody wrote down who
/// started it and when.
///
/// Wicker Eddies' dares are about being *seen*. Spells are about the unseen.
/// A spell that is really a dare belongs to him.
enum SpellRegistry {
    static let corePackID = "core-spells"

    static let bundledPacks: [SpellPack] = [
        SpellPack(
            id: corePackID,
            displayName: "Things To Go And Do",
            version: "2.0",
            author: "The Book",
            availability: .bundledFree,
            spells: coreSpells
        )
    ]

    static var enabledPacks: [SpellPack] {
        bundledPacks.filter { $0.availability != .locked }
    }

    static var all: [SpellDef] { enabledPacks.flatMap(\.spells) }

    static func spell(id: String) -> SpellDef? { all.first { $0.id == id } }

    /// What the Magic submenu offers. Capped: a Book that offers forty spells is
    /// a catalogue, and a catalogue is not a decision.
    static let offeredAtOnce = 4

    static let coreSpells: [SpellDef] = [

        // MARK: Doors and thresholds

        SpellDef(
            id: "first-footing-small",
            title: "Carry something in through a door",
            practice: "First-footing",
            source: .folk,
            blurb: "In Scotland the first person over the doorstep after midnight on New Year decides what kind of year the house gets. They must never come empty-handed. Coal, salt, bread, something to drink. People plan who goes first for days.",
            invitation: "Before you go through the next door, pick up something small to carry in with you. Decide what you're bringing into the room before you touch the handle.",
            rule: "Don't go through empty-handed. Not this time.",
            ask: "Which door was it, and what did you carry over?",
            answer: "The room got a present. Rooms remember who brings them things.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["threshold", "house"],
            packID: corePackID, weight: 3,
            symbolName: "door.left.hand.open", accent: "gold"
        ),
        SpellDef(
            id: "saining",
            title: "Tell a room what it's for",
            practice: "Saining",
            source: .folk,
            blurb: "At New Year, people in Scotland filled the house with juniper smoke. They sprinkled river water in every room. Then somebody said out loud what the house was for. Rooms forget what they're for. Somebody has to tell them.",
            invitation: "Pick one room. Open a window to let the old air out. Stand in the middle and say out loud what this room is for now.",
            rule: "Out loud. Thinking it doesn't count. Rooms can't read minds.",
            ask: "Which room, and what's it for now? One word is plenty.",
            answer: "It knows now. Watch it try.",
            mechanic: .nameSomething,
            trigger: nil,
            tags: ["house", "indoors", "naming"],
            packID: corePackID, weight: 3,
            symbolName: "wind", accent: "green"
        ),
        SpellDef(
            id: "witch-marks",
            title: "Find a mark somebody cut to keep things out",
            practice: "Apotropaic marks",
            source: .folk,
            blurb: "People cut daisy wheels and tangled knots into doorframes, beams and fireplaces so bad things couldn't get in. Anything that came in the night was supposed to follow the line round and round forever. Loads of them are still there, still on duty. Nobody told you to look.",
            invitation: "Go and look properly at an old doorway, a beam, a gate or a windowsill. Find one mark somebody made there on purpose. A circle, a scratch, a date, some initials.",
            rule: "Touch it once, gently. Then leave it to its work.",
            ask: "Where was it, and what did it look like?",
            answer: "Somebody's hand made that to keep something out, and it's still keeping it out. I'd like to know what.",
            mechanic: .pressAKeepsake,
            trigger: nil,
            tags: ["threshold", "outdoors", "old"],
            packID: corePackID, weight: 3,
            symbolName: "seal", accent: "amber"
        ),
        SpellDef(
            id: "dont-look-back",
            title: "Leave without looking back",
            practice: "Don't look back (Orpheus, Lot's wife)",
            source: .folk,
            blurb: "Orpheus walked the whole way up out of the underworld and looked back on the very last step. Lot's wife looked back at the burning city and turned into salt. Every story says the same thing. Leaving is a spell, and looking back breaks it.",
            invitation: "Leave the next place you're in without looking back. Not once. Not until you've turned a corner.",
            rule: "If you look back, you have to go back in and leave again.",
            ask: "What did you want to turn round for?",
            answer: "You didn't turn round. It's behind you now. It can stay there.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["threshold", "walk", "taboo"],
            packID: corePackID, weight: 5,
            symbolName: "eye.slash", accent: "violet"
        ),

        // MARK: Names

        SpellDef(
            id: "name-a-tree",
            title: "Tell a tree its name",
            practice: "Naming trees",
            source: .folk,
            blurb: "Trees used to have names. The Hanging Oak. The Crying Tree. The Major Oak, where Robin Hood is supposed to have hidden. Once a tree has a name you can't walk past it like it's furniture. It's somebody.",
            invitation: "Find a tree you walk past a lot. Stand close enough that it can hear you. Tell it its name, out loud.",
            rule: "From now on you say hello when you pass it. That's the deal.",
            ask: "What's the tree called?",
            answer: "I've written it down. Don't forget your side of it.",
            mechanic: .nameSomething,
            trigger: nil,
            tags: ["tree", "outdoors", "naming"],
            packID: corePackID, weight: 4,
            symbolName: "tree", accent: "green"
        ),
        SpellDef(
            id: "secret-name",
            title: "Give yourself a secret name",
            practice: "True names (Rumpelstiltskin, the Brothers Grimm)",
            source: .folk,
            blurb: "In the old stories, whoever knows your true name has power over you. Rumpelstiltskin lost everything the second the queen said his. So people kept their real names hidden and went about with everyday ones. Everybody you know only knows your everyday one.",
            invitation: "Choose a name for yourself that nobody else knows. Not a nickname. A secret one. The name you'd answer to in a forest.",
            rule: "Never tell anyone. Not even me.",
            ask: "Don't write the name here. Just sign that you've got one.",
            answer: "I'm not going to ask. Don't you dare tell me.",
            countersigns: ["I've got one.", "I've got one. It's good.", "I've got one. It's a bit much."],
            mechanic: .countersign,
            trigger: nil,
            tags: ["naming", "secret", "taboo"],
            packID: corePackID, weight: 4,
            symbolName: "key", accent: "violet"
        ),

        // MARK: Gifts to the unseen

        SpellDef(
            id: "leave-a-gift",
            title: "Leave a gift for whoever finds it",
            practice: "Gifts for the fair folk, and BookCrossing, Ron Hornbaker, 2001",
            source: .folk,
            blurb: "People used to leave milk and bread on the step for the fair folk, and never watched to see who took it. In 2001 Ron Hornbaker started leaving books in public places for strangers to find. Now there are millions of them out there, drifting about on their own.",
            invitation: "Write one true, kind sentence on a scrap of paper. Leave it where a stranger will find it. Inside a library book, on a bus seat, under a stone on a wall.",
            rule: "Walk away. Don't stay to see who finds it.",
            ask: "What did you write, and where did you leave it?",
            answer: "Now there's a bit of you out there on its own. Somebody's going to have a strange minute because of you.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["gift", "people", "outdoors"],
            packID: corePackID, weight: 5,
            symbolName: "gift", accent: "rose"
        ),
        SpellDef(
            id: "brownie-kindness",
            title: "Do a kindness nobody can trace",
            practice: "The brownie, and random kindness, Anne Herbert, 1982",
            source: .folk,
            blurb: "A brownie lived in the house and did the jobs at night. Swept, mended, churned the butter. The one rule was that nobody could thank it. Thank a brownie and it leaves forever. In 1982 Anne Herbert wrote about random kindness on a placemat, and it went round the world.",
            invitation: "Do one good thing for somebody today and make sure they never find out it was you. Put a thing back. Fix a thing. Leave a thing.",
            rule: "If they thank you, it didn't count. Start again.",
            ask: "What did you do? I won't tell anyone.",
            answer: "Nobody saw. That's the whole trick, and you did it.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["gift", "people", "secret"],
            packID: corePackID, weight: 5,
            symbolName: "sparkles", accent: "rose"
        ),
        SpellDef(
            id: "thank-a-thing",
            title: "Thank something that's been working hard",
            practice: "Hari-Kuyō, the needle memorial (Japan)",
            source: .folk,
            blurb: "In Japan, people hold a funeral for broken sewing needles. They push them into soft tofu so they can rest after a hard life of poking through cloth. The things in your house work for you for years and nobody ever says anything.",
            invitation: "Pick something you use every day without noticing. A mug, a coat, a door handle, the kettle. Thank it out loud. Properly. Say what it's done for you.",
            rule: "Say it where somebody could hear you. Whispering to kettles is cheating.",
            ask: "What was it?",
            answer: "It's been waiting years for that.",
            mechanic: .pressAKeepsake,
            trigger: nil,
            tags: ["house", "object", "gratitude"],
            packID: corePackID, weight: 5,
            symbolName: "hands.sparkles", accent: "gold"
        ),
        SpellDef(
            id: "warn-the-good-people",
            title: "Warn them before you pour",
            practice: "Warning the Good People (Irish custom)",
            source: .folk,
            blurb: "In Ireland people used to call out a warning before they threw water out of the door at night. In case one of the Good People was passing on the path. Nobody wanted to soak a fairy. Fairies don't forget that sort of thing.",
            invitation: "Every time you pour something away today, water, tea, the washing-up, call out \u{201C}Mind yourselves!\u{201D} first. Out loud. Even indoors.",
            rule: "Every time. They'll remember if you're rude once.",
            ask: "Sign it when you've done it. Tell me if anybody heard you.",
            answer: "Very polite. They like polite.",
            countersigns: ["Done.", "Done. Somebody heard.", "Done. Felt watched."],
            mechanic: .countersign,
            trigger: nil,
            tags: ["house", "water", "fair-folk"],
            packID: corePackID, weight: 4,
            symbolName: "drop", accent: "slate"
        ),
        SpellDef(
            id: "carry-a-stone",
            title: "Carry a stone all day, then give it away",
            practice: "Carrying a luck piece",
            source: .folk,
            blurb: "People have always carried small things in their pockets. A stone with a hole in it. A conker. A rabbit's foot. That one was bad luck for the rabbit. A thing gets heavier the longer you carry it. Not heavier to lift. The other kind.",
            invitation: "Pick up one small stone, leaf or button. Carry it in your pocket all day. Every time your hand finds it, notice where you are.",
            rule: "Before bed, give it away. Leave it somewhere new. You don't get to keep it.",
            ask: "What was it, and where did you leave it?",
            answer: "It's somebody else's now. It's been further than most stones get to go.",
            mechanic: .pressAKeepsake,
            trigger: nil,
            tags: ["gift", "object", "outdoors"],
            packID: corePackID, weight: 4,
            symbolName: "leaf", accent: "green"
        ),
        SpellDef(
            id: "ugliest-thing",
            title: "Be kind to the ugliest thing here",
            practice: "The Loathly Lady (Arthurian tales)",
            source: .folk,
            blurb: "Sir Gawain married the ugliest woman at King Arthur's court, and was kind to her, and she turned out to be under a spell. The stories are full of this. The ugly one's always the one with the secret. So you'd better be nice to it.",
            invitation: "Find the ugliest thing where you are. Photograph it properly, like it's beautiful. Then say one nice thing to it.",
            rule: "Mean it. It'll know if you don't.",
            ask: "What is it, and what did you say to it?",
            answer: "Nobody's been nice to that in years. Keep an eye on it.",
            mechanic: .pressAKeepsake,
            trigger: nil,
            tags: ["photo", "indoors", "attention"],
            packID: corePackID, weight: 4,
            symbolName: "camera", accent: "ink"
        ),

        // MARK: Vows and taboos

        SpellDef(
            id: "hold-your-tongue",
            title: "Say nothing until you see a bird",
            practice: "The dumb supper (Hallowe'en custom)",
            source: .folk,
            blurb: "On Hallowe'en in Britain and America, people used to lay a supper for the dead and eat it in total silence. One word and it was spoiled. Silence is a door. Most people never keep it long enough to find out where it goes.",
            invitation: "From now, say nothing at all until you see a bird. No talking, no humming, not even hm. Messages count as talking.",
            rule: "If you speak first, it doesn't count. Start again.",
            ask: "What bird was it? And what was the first thing you said after?",
            answer: "First words after a silence are heavy ones. I'm keeping yours.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["speech", "silence", "creature", "taboo"],
            packID: corePackID, weight: 3,
            symbolName: "speaker.slash", accent: "slate"
        ),
        SpellDef(
            id: "three-times-sunwise",
            title: "Go round it three times",
            practice: "Going deiseal, sunwise (Ireland and Scotland)",
            source: .folk,
            blurb: "In Ireland and Scotland people walked three times round a holy well, a cairn, even a sick person's bed. Always the way the sun goes. Going the other way round was called widdershins, and that was for curses. Everybody knew which way was which.",
            invitation: "Before you decide anything today, walk round something three times the way the sun goes. A tree, a lamp post, the kitchen table. Then decide.",
            rule: "Sunwise only. Widdershins is for curses and I'm not helping with those.",
            ask: "What did you walk round, and what did you decide?",
            answer: "Three times, sunwise. Whatever you decided has been walked round properly now.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["circle", "decision", "folk"],
            packID: corePackID, weight: 4,
            symbolName: "arrow.clockwise", accent: "gold"
        ),
        SpellDef(
            id: "one-new-question",
            title: "Ask the question you've never asked",
            practice: "Asking properly",
            source: .folk,
            blurb: "You can know somebody for thirty years and never ask them anything new. The questions run out and you just talk about the weather. In the stories the hero gets three questions and has to spend them well. You get as many as you want and you're wasting them.",
            invitation: "Ask somebody you know well one question you've really never asked them.",
            rule: "Then be quiet and listen to all of the answer.",
            ask: "Sign it once you've asked. Not before.",
            answer: "Now you know one more thing about them than you did this morning. That's not a small thing.",
            countersigns: ["Asked.", "Asked. They were surprised.", "Asked. I was surprised."],
            mechanic: .countersign,
            trigger: nil,
            tags: ["people", "speech", "attention"],
            packID: corePackID, weight: 5,
            symbolName: "bubble.left.and.bubble.right", accent: "rose"
        ),

        // MARK: Oracles

        SpellDef(
            id: "bibliomancy",
            title: "Ask a book",
            practice: "Bibliomancy",
            source: .folk,
            blurb: "You ask a question, open a book anywhere, and the first line your eye lands on is the answer. People did it with Virgil for a thousand years. In Iran they still do it with Hafez, all night, on the longest night of the year. Books know more than they let on.",
            invitation: "Hold a question in your head. Take any book within reach. Open it anywhere and read the first line you see.",
            rule: "The first line. Don't pick a better one. Books can tell.",
            ask: "Write the line down, and the book it fell out of. Then tell me what it said to your question.",
            answer: "That's your answer. What it means is your job. I only open the doors.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["book", "chance", "indoors", "oracle"],
            packID: corePackID, weight: 4,
            symbolName: "text.quote", accent: "violet"
        ),
        SpellDef(
            id: "throw-the-bones",
            title: "Let me throw the bones for you",
            practice: "Astragalomancy, ancient Greece",
            source: .folk,
            blurb: "Before anybody made dice, people threw knucklebones to get answers. Sheep's ankle bones, four sides each. The Greeks threw them in temples and asked the gods to steer them. I've got a pair. I keep them in my spine.",
            invitation: "Ask a question that has a yes or a no in it. Ask it properly, in your head, like you mean it. Then let me throw.",
            rule: "One throw. If you don't like it you still don't get another.",
            ask: "Throw them. Then write down what you asked, so we both know what they were answering.",
            answer: "The bones don't explain themselves. Neither do I.",
            mechanic: .throwTheBones,
            trigger: nil,
            tags: ["chance", "oracle"],
            packID: corePackID, weight: 3,
            symbolName: "dice", accent: "violet"
        ),
        SpellDef(
            id: "counting-magpies",
            title: "Count the magpies",
            practice: "Counting magpies",
            source: .folk,
            blurb: "One for sorrow, two for joy, three for a girl, four for a boy, five for silver, six for gold, seven for a secret never to be told. That's the magpie rhyme, and people in Britain still count. If they see one on its own they say good morning to it, so it isn't cross.",
            invitation: "Go outside and count the first magpies you see together. If there aren't magpies where you live, crows will do. Find your number in the rhyme.",
            rule: "The first ones only. No waiting about for a better number. If there's one alone, say good morning to it.",
            ask: "How many, and which line of the rhyme did you get?",
            answer: "That's your line for today. Carry it carefully.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["creature", "outdoors", "chance", "oracle"],
            packID: corePackID, weight: 3,
            symbolName: "bird", accent: "slate"
        ),
        SpellDef(
            id: "exact-overheard",
            title: "Take a stranger's words as your answer",
            practice: "Kledon, ancient Greece",
            source: .folk,
            blurb: "In ancient Greece, if you had a question you went to the market and listened. The first words a stranger said, about anything at all, were your answer. They called it a kledon. The stranger never knew they'd answered anything.",
            invitation: "Hold a question in your head. Go somewhere with people in it. The first thing you overhear is your answer. Write it exactly as it was said.",
            rule: "Don't tidy it. The broken bit is part of the answer.",
            ask: "What did they say? Exactly. And what was your question?",
            answer: "People are very wise when they don't know you're listening.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["people", "sound", "words", "oracle"],
            packID: corePackID, weight: 4,
            symbolName: "ear", accent: "rose"
        ),
        SpellDef(
            id: "shufflemancy",
            title: "Let the shuffle answer",
            practice: "Shufflemancy",
            source: .folk,
            blurb: "You ask a question, press shuffle, and the first line you hear is the answer. Nobody invented this one. People everywhere started doing it on their own, as soon as music went into their pockets. Old magic always finds the new doors.",
            invitation: "Ask your question in your head. Shuffle everything. Listen for the first whole line of words.",
            rule: "The first line, not the best one. Skipping is cheating and the shuffle knows.",
            ask: "Write the line down, and the question it was answering.",
            answer: "Funny how it knew. I'm not saying anything.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["music", "chance", "indoors", "oracle"],
            packID: corePackID, weight: 3,
            symbolName: "shuffle", accent: "rose"
        ),
        SpellDef(
            id: "camera-roll-bibliomancy",
            title: "Let your photos answer",
            practice: "Bibliomancy, done to a phone",
            source: .folk,
            blurb: "This is the old book trick, done to the thing in your pocket. You already do it by accident, every time you scroll back too far and stop on a face you'd forgotten. Doing it on purpose is different.",
            invitation: "Ask a question in your head. Scroll your photos fast with your eyes half shut, and stop without choosing. That photo is your answer.",
            rule: "No scrolling on to a better one.",
            ask: "What's in the photo, and what did you ask?",
            answer: "You took that for yourself ages ago. You didn't know what it was for yet.",
            mechanic: .pressAKeepsake,
            trigger: nil,
            tags: ["photo", "chance", "memory", "oracle"],
            packID: corePackID, weight: 3,
            symbolName: "photo.stack", accent: "gold"
        ),
        SpellDef(
            id: "blackout-poem",
            title: "Find the secret sentence in a page",
            practice: "Blackout poetry, Tom Phillips, 1966",
            source: .folk,
            blurb: "Tom Phillips bought an old novel in 1966 and spent fifty years crossing most of it out. What was left on each page was a poem that'd been hiding in there all along. He never added a word. Every page you've ever read has one.",
            invitation: "Take any printed page you don't need. A leaflet, a receipt, an old letter. Cross out everything except the sentence that was hiding in it.",
            rule: "Only cross out. Never add a word.",
            ask: "What was hiding in there?",
            answer: "It was in there the whole time. Somebody had to let it out.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["word", "paper", "indoors", "secret"],
            packID: corePackID, weight: 3,
            symbolName: "rectangle.and.pencil.and.ellipsis", accent: "ink"
        ),
        SpellDef(
            id: "network-omens",
            title: "Read the network names",
            practice: "Router divination",
            source: .academy,
            blurb: "The Academy says the names people give their routers are omens. It's the only naming most people ever do where strangers can read it. There's no evidence for this at all. Wispwood has a chart anyway.",
            invitation: "Hold a question in your head. Open the list of networks near you. The strangest name on it's your answer.",
            rule: "Only the strangest one. Not the funniest. Those are different.",
            ask: "What was the name, and what was your question?",
            answer: "Somebody chose that name. Somebody's been answering your question for months and didn't know.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["chance", "indoors", "academy", "oracle"],
            packID: corePackID, weight: 2,
            symbolName: "wifi", accent: "slate"
        ),

        // MARK: Strangers and the road

        SpellDef(
            id: "ask-the-way",
            title: "Ask a stranger the way",
            practice: "The helper by the road (nearly every fairy tale)",
            source: .folk,
            blurb: "In the old stories the hero always meets somebody by the road. An old woman, a fox, a man with one shoe. The one who stops and asks gets where they're going. The one who walks past gets eaten. Nobody asks strangers the way any more. Phones do it.",
            invitation: "Ask somebody the way to a place you already know how to get to. Say thank you properly. Then go their way, not yours.",
            rule: "Follow their way exactly, even if it's longer.",
            ask: "What did their way have in it that yours doesn't?",
            answer: "You were the one who stopped and asked. In the stories, that one does fine.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["people", "walk", "outdoors"],
            packID: corePackID, weight: 5,
            symbolName: "signpost.right", accent: "rose"
        ),
        SpellDef(
            id: "sonder",
            title: "Give a stranger a secret life",
            practice: "Sonder, John Koenig, 2012",
            source: .folk,
            blurb: "John Koenig made up this word in 2012. It's for the moment you realise a stranger has a life as big and messy as yours. In the old stories any stranger could be a king in disguise, or a fox, or somebody's lost brother. You never knew. You still don't.",
            invitation: "Pick one stranger. Give them a job, a worry, a secret, and somewhere they're going. Make it dull and exact. Then let them go.",
            rule: "Don't stare. Look the way cats look.",
            ask: "Who were they, really?",
            answer: "They'll never know you did that. Now they've got two lives.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["people", "outdoors", "attention"],
            packID: corePackID, weight: 4,
            symbolName: "person.2", accent: "rose"
        ),

        // MARK: Leaving the path

        SpellDef(
            id: "derive",
            title: "Take the turn you never take",
            practice: "The dérive, Guy Debord, 1956",
            source: .folk,
            blurb: "Guy Debord wrote this down in 1956. You walk with nowhere to go and let the streets pull you. He thought cities had currents in them, like rivers, and most people only ever swim the same bit. The whole trick is refusing your usual way.",
            invitation: "Go out and take the turn you never take. Then take the wrong one again. Keep going until something stops you.",
            rule: "No map. If you see somewhere you know, turn away from it.",
            ask: "Where did you end up? Give the place a name.",
            answer: "You got lost on purpose. Hardly anybody does that any more.",
            mechanic: .nameSomething,
            trigger: nil,
            tags: ["walk", "outdoors", "place"],
            packID: corePackID, weight: 5,
            symbolName: "arrow.triangle.turn.up.right.diamond", accent: "violet"
        ),
        SpellDef(
            id: "crossroads",
            title: "Let the crossroads choose",
            practice: "Crossroads lore",
            source: .folk,
            blurb: "Crossroads are where things happen in stories. Hecate waited at them. Musicians went to them at midnight to make deals. People buried things there that they wanted to stay buried. A crossroads is a place that hasn't made up its mind.",
            invitation: "Walk to the nearest place where two roads or paths cross. Stand in the middle of your choices. Take the way you've been down least.",
            rule: "No phone. The crossroads is choosing, not you.",
            ask: "Where did it take you? Give the place a name.",
            answer: "The crossroads picked. Now you owe it a visit back one day.",
            mechanic: .nameSomething,
            trigger: nil,
            tags: ["walk", "outdoors", "place"],
            packID: corePackID, weight: 4,
            symbolName: "arrow.triangle.branch", accent: "slate"
        ),
        SpellDef(
            id: "leaving-route",
            title: "Go home the way you'd leave",
            practice: "Reversing the route",
            source: .folk,
            blurb: "You've got one way home and you stopped choosing it years ago. Your feet do it now. Go the way you'd go if you were setting off instead of coming back, and the street puts different things in front of you.",
            invitation: "Go home by the way you'd take if you were leaving. Different turns, same door at the end.",
            rule: "Your feet will try to take the old way. Don't let them.",
            ask: "What did you pass that you'd forgotten was there? Name it.",
            answer: "Your feet are sulking. Good.",
            mechanic: .nameSomething,
            trigger: nil,
            tags: ["walk", "outdoors", "routine"],
            packID: corePackID, weight: 4,
            symbolName: "arrow.uturn.left", accent: "green"
        ),

        // MARK: In the house

        SpellDef(
            id: "wrong-chair",
            title: "Sit in somebody else's chair",
            practice: "Goldilocks, Robert Southey, 1837",
            source: .folk,
            blurb: "Robert Southey wrote down the story of the three bears in 1837. In his version the one sitting in their chairs wasn't a little girl. She was a rude old woman. Everybody's got a chair nobody else sits in, and nobody agreed to it out loud.",
            invitation: "Sit in a chair that belongs to somebody else. Stay till it gets comfortable. Look at the room from there.",
            rule: "Get up before they come back.",
            ask: "What can you see from there that you can't see from yours?",
            answer: "Now you know what the room looks like to somebody else. Don't tell them you were there.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["house", "indoors", "attention"],
            packID: corePackID, weight: 4,
            symbolName: "chair", accent: "amber"
        ),
        SpellDef(
            id: "count-your-mugs",
            title: "Count what the Borrowers took",
            practice: "The Borrowers, Mary Norton, 1952",
            source: .folk,
            blurb: "Mary Norton wrote about the Borrowers in 1952. Tiny people under the floor who take safety pins and odd socks and pencil ends, and build whole houses out of them. Everybody's lost a sock to somebody. Nobody's ever counted properly.",
            invitation: "Guess how many you own of one small thing. Socks, pens, hair ties, teaspoons. Then go and count them all.",
            rule: "Write the guess down before you count. No changing it.",
            ask: "Both numbers. If they don't match, somebody's borrowing.",
            answer: "I'd check under the floorboards. I'm only saying.",
            mechanic: .findOneLine,
            trigger: nil,
            tags: ["house", "indoors", "counting"],
            packID: corePackID, weight: 3,
            symbolName: "cup.and.saucer", accent: "slate"
        ),

        // MARK: Weather — these do not exist when the sky is wrong

        SpellDef(
            id: "rain-listening",
            title: "Listen to what the rain is landing on",
            practice: "Listening to rain",
            source: .folk,
            blurb: "Rain sounds different on a car roof, a leaf, a puddle, a bin lid. The world's drawing you a map of itself out of sound. And most people are indoors with the window shut.",
            invitation: "Stand where you can hear it. Pick out three different things it's landing on.",
            rule: "Eyes shut the whole time.",
            ask: "What was the one you had to work hardest to hear?",
            answer: "The rain was telling you where everything is. Not many people bother listening.",
            mechanic: .findOneLine,
            trigger: PageTrigger(weatherTags: ["rain"]),
            tags: ["weather", "sound", "rain"],
            packID: corePackID, weight: 4,
            symbolName: "cloud.rain", accent: "slate"
        ),
        SpellDef(
            id: "fog-walking",
            title: "Walk into the fog on purpose",
            practice: "The dérive, in bad visibility",
            source: .folk,
            blurb: "Fog eats distance. It takes a street you've walked a thousand times and only gives you back the next few steps of it. In the old stories, fog's where people wander off into the other world. They usually came back. Usually.",
            invitation: "Go out and walk toward something you can't see yet. Keep going until it shows up.",
            rule: "Don't use your phone to find it. Let the fog give it back.",
            ask: "What came out of the fog? Name the moment it did.",
            answer: "The fog gave it back. It doesn't always.",
            mechanic: .nameSomething,
            trigger: PageTrigger(weatherTags: ["fog"]),
            tags: ["weather", "walk", "fog"],
            packID: corePackID, weight: 5,
            symbolName: "cloud.fog", accent: "slate"
        ),
        SpellDef(
            id: "first-tracks",
            title: "Be the first to walk on it",
            practice: "First tracks",
            source: .folk,
            blurb: "Snow puts a clean page over everything you own, and it doesn't last. Skiers have a word for getting to it first, and they set alarms for it. They're right to.",
            invitation: "Go out before anyone else has walked on it. Walk somewhere. Then turn and look at your own tracks.",
            rule: "Walk it once. No going back over your own steps.",
            ask: "What did you pick up where you stopped?",
            answer: "For a little while you were the only person who'd ever been there.",
            mechanic: .pressAKeepsake,
            trigger: PageTrigger(weatherTags: ["snow"]),
            tags: ["weather", "snow", "outdoors"],
            packID: corePackID, weight: 5,
            symbolName: "snowflake", accent: "ice"
        ),
        SpellDef(
            id: "counting-the-storm",
            title: "Count how far away Thor is",
            practice: "Flash-to-bang counting",
            source: .folk,
            blurb: "The Norse said thunder was Thor's chariot rolling across the sky, pulled by two goats. Sailors and farmers counted the gap between the flash and the bang to see how far off he was. About three seconds for every kilometre. Counting works on gods too.",
            invitation: "Count out loud from the flash to the thunder. Divide by three. That's how many kilometres away he is.",
            rule: "Out loud. Thunder likes to be counted.",
            ask: "How far away was he? Coming closer, or going?",
            answer: "You counted a god. Most people just jump.",
            mechanic: .findOneLine,
            trigger: PageTrigger(weatherTags: ["storm"]),
            tags: ["weather", "storm", "counting"],
            packID: corePackID, weight: 4,
            symbolName: "bolt", accent: "violet"
        ),
        SpellDef(
            id: "sharpest-shadow",
            title: "Check your shadow's still attached",
            practice: "Shadow lore, and Peter Pan, J. M. Barrie, 1904",
            source: .folk,
            blurb: "In old German stories a man who sold his shadow was the scariest person in the village. Peter Pan lost his in 1904, in a nursery drawer, and Wendy had to sew it back on. People used to check. On a bright day, you can.",
            invitation: "Go out in the sun and find your shadow. Wave at it. Jump. Try to make it do something you didn't.",
            rule: "Don't step on its head. It's rude.",
            ask: "What did your shadow do?",
            answer: "Still attached. Good. Keep an eye on it.",
            mechanic: .findOneLine,
            trigger: PageTrigger(weatherTags: ["bright"]),
            tags: ["weather", "light", "outdoors"],
            packID: corePackID, weight: 3,
            symbolName: "sun.max", accent: "gold"
        ),
        SpellDef(
            id: "visible-breath",
            title: "Say it where you can see your breath",
            practice: "Breath-saining",
            source: .academy,
            blurb: "The Academy holds that a thing said where you can see your breath's been let out properly, because you can watch it go. There's no evidence for this. Duskthorn says the cold carries words further. There's no evidence for that either.",
            invitation: "Go outside where the cold makes your breath show. Say the thing you haven't said. Watch it go.",
            rule: "Say all of it. Half a thing in the cold just freezes.",
            ask: "Sign when you've let it go. You don't have to tell me what it was.",
            answer: "Gone. The cold's got it now.",
            countersigns: ["Said it.", "Said it. Watched it go."],
            mechanic: .countersign,
            trigger: PageTrigger(weatherTags: ["cold", "frost"]),
            tags: ["weather", "cold", "academy"],
            packID: corePackID, weight: 3,
            symbolName: "wind.snow", accent: "ice"
        ),

        // MARK: Places — these turn up when you are somewhere

        SpellDef(
            id: "wrong-stone",
            title: "Look for a stone with a hole in it",
            practice: "Hag stones",
            source: .folk,
            blurb: "A stone with a hole worn right through it's a hag stone. People hung them over doors and on bedposts. Look through the hole and you're supposed to see the fair folk as they really are. They're rare. That's the point.",
            invitation: "Turn over stones until you find one with a hole in it. If there isn't one, keep the stone that's most wrong. Wrong colour, wrong shape, wrong everything.",
            rule: "Keep only one. The beach needs the rest.",
            ask: "What did you find? If it had a hole, what did you see through it?",
            answer: "In my Pocket it goes. I'll look through it when you're not watching.",
            mechanic: .pressAKeepsake,
            trigger: PageTrigger(placeKinds: ["beach", "marina"]),
            tags: ["place", "beach", "outdoors", "fair-folk"],
            packID: corePackID, weight: 5,
            symbolName: "water.waves", accent: "green"
        ),
        SpellDef(
            id: "give-the-water",
            title: "Give the water something",
            practice: "Offerings to water (wells, lakes, fountains)",
            source: .folk,
            blurb: "People have thrown things into water for thousands of years. Swords into lakes. Bent pins into wells. Coins into every fountain you've ever seen. Nobody throws something into water and asks for it back. That's what makes it a gift.",
            invitation: "Find water. A fountain, a pond, the sea. Give it something small you won't miss. A coin, a pebble, a petal. Make the wish before it lands.",
            rule: "Don't say the wish out loud. Water keeps secrets. People don't.",
            ask: "Sign it once the water has it.",
            answer: "The water has it now. Don't go looking for it.",
            countersigns: ["It sank.", "It sank. I wished.", "It floated. Hm."],
            mechanic: .countersign,
            trigger: PageTrigger(placeKinds: ["park", "beach", "marina"]),
            tags: ["place", "water", "gift"],
            packID: corePackID, weight: 4,
            symbolName: "drop.circle", accent: "slate"
        ),
        SpellDef(
            id: "follow-a-bird",
            title: "Follow a bird until you lose it",
            practice: "Augury",
            source: .folk,
            blurb: "The Romans watched birds to read what the gods wanted, and got it wrong all the time. The watching part still works, though. A bird takes your eyes somewhere you'd never have pointed them. In the stories, that's how you find the door.",
            invitation: "Pick a bird and follow it with your eyes until it goes somewhere you can't.",
            rule: "Don't look away first. Let it be the one to go.",
            ask: "Where did you end up looking?",
            answer: "That's where it wanted you to look. Probably. Birds don't say.",
            mechanic: .findOneLine,
            trigger: PageTrigger(placeKinds: ["park", "beach", "marina"]),
            tags: ["creature", "outdoors", "attention"],
            packID: corePackID, weight: 4,
            symbolName: "bird", accent: "green"
        ),
        SpellDef(
            id: "unwalked-aisle",
            title: "Walk the aisle you never go down",
            practice: "Goblin Market, Christina Rossetti, 1862",
            source: .folk,
            blurb: "Christina Rossetti wrote about goblins selling fruit in 1862. Strange fruit, and the girls were told never to taste it. Every shop has an aisle like that. The one you've walked past every week for years without once turning down it.",
            invitation: "Walk one aisle you've never had any reason to go down. Read the labels properly.",
            rule: "Look, but take nothing home. That's the goblin rule.",
            ask: "What's the strangest thing down there that somebody, somewhere, needs?",
            answer: "Somebody needs that. Somebody's whole week depends on it.",
            mechanic: .findOneLine,
            trigger: PageTrigger(placeKinds: ["store", "foodMarket", "bakery", "pharmacy"]),
            tags: ["place", "indoors", "walk"],
            packID: corePackID, weight: 4,
            symbolName: "cart", accent: "amber"
        ),
        SpellDef(
            id: "shelf-next-door",
            title: "Take the book beside the one you came for",
            practice: "Shelf divination",
            source: .folk,
            blurb: "Libraries put books about the same thing next to each other. So the book beside the one you wanted is by somebody who thinks something different. They've been sitting side by side for years, not talking.",
            invitation: "Find the book you'd have come for. Take the one right next to it instead. Open it anywhere.",
            rule: "The one on the right. Not the one you like the look of.",
            ask: "Give me a line from it, and the title.",
            answer: "That book's been waiting on that shelf for somebody. It got you.",
            mechanic: .findOneLine,
            trigger: PageTrigger(placeKinds: ["library", "bookstore"]),
            tags: ["place", "book", "indoors", "oracle"],
            packID: corePackID, weight: 4,
            symbolName: "books.vertical", accent: "ink"
        ),
        SpellDef(
            id: "boat-names",
            title: "Read the names of the boats",
            practice: "Boat-naming",
            source: .folk,
            blurb: "Every boat in a harbour was named by somebody who had to paint it on the side where everyone could see. Sailors say it's bad luck to change a boat's name once it has one. Some of them are jokes. Some of them are wives. One of them was named in a mood.",
            invitation: "Read the names along the water until you find the one that was named in a mood.",
            rule: "Read every one before you choose. Boats notice.",
            ask: "Which one, and what was the mood?",
            answer: "They'll be stuck with that name forever now. So will you.",
            mechanic: .findOneLine,
            trigger: PageTrigger(placeKinds: ["marina", "beach"]),
            tags: ["place", "water", "naming"],
            packID: corePackID, weight: 3,
            symbolName: "sailboat", accent: "green"
        ),
        SpellDef(
            id: "order-otherwise",
            title: "Order the thing you never order",
            practice: "Breaking a standing order",
            source: .academy,
            blurb: "The Academy holds that anywhere you've had the same thing more than four times has stopped being a place you visit. It's a route you run. Duskthorn calls that the smallest curse there is. The Academy can't prove any of it.",
            invitation: "Order the thing you never order. Not the one you'd like. The one you've never once thought about.",
            rule: "Finish it. That's the price.",
            ask: "What was it, and were you right to avoid it all this time?",
            answer: "The place has seen a different you now. It won't forget.",
            mechanic: .findOneLine,
            trigger: PageTrigger(placeKinds: ["cafe", "restaurant", "bakery", "brewery"]),
            tags: ["place", "indoors", "routine", "academy"],
            packID: corePackID, weight: 5,
            symbolName: "cup.and.saucer", accent: "amber"
        ),

        // MARK: Hours — time bands are dawn, day, dusk and night

        SpellDef(
            id: "before-you-speak",
            title: "Say what you want before you say anything else",
            practice: "First words",
            source: .folk,
            blurb: "The first words out of your mouth used to count. Children in Britain still say rabbit, rabbit on the first of the month before they say anything else. Most mornings now the first thing anybody says is to a phone, or a complaint about the time.",
            invitation: "Before you say one word to anybody, say out loud what you want out of today. One sentence. To the window, if you like.",
            rule: "Before anything else. If you've already spoken, it's too late for today.",
            ask: "Sign it, so you can't pretend later you didn't say it.",
            answer: "Said. Out loud. Now today knows what you want. That's more than most days get told.",
            countersigns: ["Said it.", "Said it. Meant it.", "Said it to the window."],
            mechanic: .countersign,
            trigger: PageTrigger(timeBands: ["dawn"]),
            tags: ["hour", "morning", "speech"],
            packID: corePackID, weight: 4,
            symbolName: "sunrise", accent: "gold"
        ),
        SpellDef(
            id: "watch-it-go",
            title: "Stay out for the in-between",
            practice: "The gloaming",
            source: .folk,
            blurb: "The old word for the end of the day is the gloaming. It's not day and it's not night. In the stories that's exactly when the strange things come out, because nobody's quite sure what they're seeing. Everyone says they like a sunset. Almost nobody stays for the part after.",
            invitation: "Go and watch the light go. Stay ten minutes past the point it stops being pretty.",
            rule: "Stay out after everybody else goes in.",
            ask: "What colour did it end on? And what did you see in the in-between?",
            answer: "You stayed for the gloaming. That's when the good bits happen.",
            mechanic: .findOneLine,
            trigger: PageTrigger(timeBands: ["dusk"]),
            tags: ["hour", "evening", "light"],
            packID: corePackID, weight: 5,
            symbolName: "sunset", accent: "rose"
        ),
        SpellDef(
            id: "first-star",
            title: "Wish on the first star",
            practice: "Star light, star bright (American rhyme, 1800s)",
            source: .folk,
            blurb: "Star light, star bright, first star I see tonight. Children in America have said that for nearly two hundred years. It has to be the first one. After that they're just stars.",
            invitation: "Go out and look for the first star. Say the whole rhyme to it. Star light, star bright, first star I see tonight, I wish I may, I wish I might, have the wish I wish tonight. Then wish.",
            rule: "Don't tell anyone the wish. Not even me.",
            ask: "Sign it once you've wished.",
            answer: "It heard you. Don't tell me. I mean it.",
            countersigns: ["Wished.", "Wished. A big one.", "Wished. It was a planet."],
            mechanic: .countersign,
            trigger: PageTrigger(timeBands: ["dusk"]),
            tags: ["hour", "sky", "wish"],
            packID: corePackID, weight: 4,
            symbolName: "star", accent: "gold"
        ),
        SpellDef(
            id: "find-something-moving",
            title: "Find one thing moving up there",
            practice: "Night-watching",
            source: .folk,
            blurb: "There's always something moving in a night sky. Satellites, planes, bats, the moon sliding past a roof if you're patient. People used to know the sky the way you know your own street. They could tell you what was up there and who put it there.",
            invitation: "Go out and look up until you find one thing that's moving. Stay with it until you lose it.",
            rule: "Don't look it up afterwards. What you decided it was is what it was.",
            ask: "What did you decide it was? Give it a name.",
            answer: "That's what it was, then. I'll take your word over the internet's.",
            mechanic: .nameSomething,
            trigger: PageTrigger(timeBands: ["night"]),
            tags: ["hour", "sky", "night"],
            packID: corePackID, weight: 4,
            symbolName: "moon.stars", accent: "violet"
        ),
        SpellDef(
            id: "lights-off",
            title: "Sit in a room you know with the lights off",
            practice: "Sitting in the dark",
            source: .academy,
            blurb: "A room you know perfectly stops being that room when you take the light out. Everything's still where you left it, and none of it's where you thought. It takes about four minutes. The Academy calls it the room showing you its other face.",
            invitation: "Turn the lights off in a room you know by heart. Sit down. Stay until your eyes catch up.",
            rule: "No phone light. Not even a peek.",
            ask: "What was the first thing you could make out?",
            answer: "Now you've met the room's other face. Say hello to it next time.",
            mechanic: .findOneLine,
            trigger: PageTrigger(timeBands: ["dusk", "night"]),
            tags: ["house", "dark", "attention"],
            packID: corePackID, weight: 4,
            symbolName: "moon.zzz", accent: "violet"
        ),
        SpellDef(
            id: "new-moon-silver",
            title: "Turn your coins over for the new moon",
            practice: "Greeting the new moon (British custom)",
            source: .folk,
            blurb: "When people in Britain saw the new moon for the first time each month, they turned over the coins in their pocket and bowed to it. They were careful never to see it first through glass. Catching it through a window was supposed to spoil the whole month.",
            invitation: "Go outside and find the new moon. Look at it with nothing in between. Turn over whatever coins you've got and bow.",
            rule: "Not through a window. Outside, or it doesn't count.",
            ask: "Sign it once you've bowed.",
            answer: "The moon sees a lot of people. It doesn't see many of them bowing.",
            countersigns: ["Turned them.", "Turned them. Bowed too.", "No coins. Bowed anyway."],
            mechanic: .countersign,
            trigger: PageTrigger(timeBands: ["dusk", "night"], moonPhases: ["Waxing Crescent"]),
            tags: ["hour", "moon", "night"],
            packID: corePackID, weight: 5,
            symbolName: "moonphase.waxing.crescent", accent: "ice"
        ),
    ]
}

/// Which spells the Book is offering, and the Page one becomes when cast.
enum SpellOffering {

    /// The spells on the Magic shelf today.
    ///
    /// Deterministic per day, so the shelf does not reshuffle under the
    /// reader's thumb while they are deciding, and so tomorrow's is a genuinely
    /// different set rather than a fresh random draw each time the menu opens.
    /// Conditions arrive in Phase 4; until then every spell is eligible.
    /// How long a worked spell stays off the shelf.
    ///
    /// Not a punishment and not an economy — it is so the Book does not hand
    /// back the same instruction the morning after, which would turn the one
    /// feature that breaks a routine into a routine.
    static let castCooldown: TimeInterval = 6 * 24 * 3_600

    static func offered(
        on dayID: String,
        context: PageTriggerContext? = nil,
        rested: Set<String> = [],
        lastCast: [String: Date] = [:],
        now: Date = Date(),
        from spells: [SpellDef] = SpellRegistry.all,
        limit: Int = SpellRegistry.offeredAtOnce
    ) -> [SpellDef] {
        guard limit > 0 else { return [] }
        let spells = spells.filter { spell in
            // Put down for good means for good.
            if rested.contains(spell.id) { return false }
            guard let worked = lastCast[spell.id] else { return true }
            let since = now.timeIntervalSince(worked)
            // A clock that has run backwards is a clock, not a decision.
            return since < 0 || since >= castCooldown
        }
        // A spell whose conditions are not met does not exist today. With no
        // context at all only the unconditional ones are offered: showing a fog
        // spell in bright sun would be worse than showing one spell fewer.
        let available = spells.filter { spell in
            guard let trigger = spell.trigger else { return true }
            guard let context else { return false }
            return trigger.allows(context: context, archetypeID: spell.id)
        }
        guard !available.isEmpty else { return [] }
        // Written out rather than chained: the fluent version defeated the
        // type-checker outright.
        var ranked: [(spell: SpellDef, score: Int)] = []
        ranked.reserveCapacity(available.count)
        for spell in available {
            // Weight tilts the draw without fixing it. A heavier spell comes up
            // more often across a season and is never guaranteed today.
            let seed: Int = abs("\(dayID)-spell-\(spell.id)".stableHash)
            // A spell that only exists because of today outranks one that works
            // any day of the year. This is the whole point of the conditions:
            // when it is foggy, the fog spell should be the one waiting.
            let earnedToday: Int = spell.trigger == nil ? 0 : 1_400
            let score: Int = (seed % 1_000) + spell.weight * 90 + earnedToday
            ranked.append((spell: spell, score: score))
        }
        ranked.sort { left, right in
            left.score == right.score ? left.spell.id < right.spell.id : left.score > right.score
        }
        return ranked.prefix(limit).map { $0.spell }
    }

    /// The metadata a cast Spell carries.
    ///
    /// The mechanic keys keep their `festival` names on purpose. They are a
    /// contract between whatever built the Page and the capture sheet that
    /// renders the affordance — not anything the reader ever sees — and reusing
    /// them means a Spell gets the whole existing mechanic UI for nothing.
    static func metadata(for spell: SpellDef, dayID: String) -> [String: String] {
        var metadata: [String: String] = [
            "spellID": spell.id,
            "spellPractice": spell.practice,
            "spellSource": spell.source.rawValue,
            "spellAnswer": spell.answer,
            "accent": spell.accent,
            "blurb": spell.blurb,
            "invitation": spell.invitation,
            "attribution": spell.attributionLine,
            "festivalMechanic": spell.mechanic.rawValue,
            // The spell's own words, never the feast's. The feast prompt for
            // `findOneLine` sends the reader to a book, and was showing under
            // spells about rain and cafes.
            "festivalMechanicTitle": spell.askTitle,
            "festivalMechanicPrompt": spell.ask,
            "festivalMechanicSymbol": spell.mechanic.symbolName,
            "placeholder": spell.placeholder,
            "tags": "spell,magic,\(spell.source.rawValue),spell:\(spell.id)",
            // The same door the feast days carry. One tap, honoured forever.
            "festivalCanRest": "true",
            "festivalRestLabel": "Don't offer me this one again"
        ]
        if let rule = spell.rule?.nonEmpty {
            metadata["spellRule"] = rule
        }
        if spell.trigger != nil {
            // Read by the Curator's spell floor: a spell the world laid out
            // today is worth a chair on the visible desk.
            metadata["spellConditional"] = "true"
        }
        if spell.mechanic == .countersign {
            metadata["countersigns"] = (spell.countersigns ?? SpellDef.defaultCountersigns)
                .joined(separator: "||")
        }
        if spell.mechanic == .pressAKeepsake {
            metadata["festivalKeepsakeGlyph"] = spell.symbolName
            metadata["festivalKeepsakeObject"] = spell.title
        }
        if spell.mechanic == .nameSomething {
            metadata["festivalNameFactID"] = "spell-name:\(spell.id)"
        }
        if spell.mechanic == .throwTheBones {
            // A spell's bones answer the question the reader asked. The feast
            // readings are about the size of the day and would ignore it.
            let bones = FeastBones.throwBones(celebrationID: spell.id, dayID: dayID)
            metadata["festivalBonesRoll"] = "\(bones.roll)"
            metadata["festivalBonesBand"] = bones.band.rawValue
            metadata["festivalBonesHeadline"] = bones.headline
            metadata["festivalBonesLine"] = SpellBones.answer(for: bones.band)
        }
        return metadata
    }

    /// The Page a Spell becomes when the reader picks it up.
    static func surface(
        for spell: SpellDef,
        dayID: String,
        now: Date = Date(),
        recall: String? = nil,
        sourceID: String = "spells",
        score: Int = 60
    ) -> SurfacePage {
        var metadata = metadata(for: spell, dayID: dayID)
        metadata["source"] = sourceID
        if let recall = recall?.nonEmpty { metadata["spellRecall"] = recall }
        let body = [spell.blurb, spell.invitation, spell.rule, recall?.nonEmpty]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        return SurfacePage(
            id: "spell-\(spell.id)-\(dayID)",
            type: .spell,
            sourceID: sourceID,
            intent: .capture,
            renderStyle: .loreLetter,
            score: score,
            reason: spell.attributionLine,
            prompt: spell.title,
            detail: spell.invitation,
            payload: BookPagePayload(
                headline: spell.title,
                body: body,
                metadata: metadata
            )
        )
    }

    /// What the Book says when the reader comes back from a spell. It takes
    /// the keep moment over from the cast, the way an authored mission's reply
    /// does: the spell has its own ending, and a generic cheer would step on it.
    static func keepNote(for surface: SurfacePage, hasReaderContribution: Bool) -> KeepMarginalia.Note? {
        guard hasReaderContribution,
              surface.type == .spell,
              let line = surface.payload.metadata["spellAnswer"]?.nonEmpty else { return nil }
        return KeepMarginalia.Note(
            castSlug: "book-sprite",
            castName: "The Book",
            assetName: "LabyrinthFaeBookSprite",
            line: line
        )
    }
}

/// The Book's bones, thrown for a yes-or-no question.
enum SpellBones {
    static func answer(for band: FeastBonesThrow.Band) -> String {
        switch band {
        case .wide:
            return "Yes. Yes so loud I nearly fell off the desk. Go on, then."
        case .open:
            return "Yes. Don't hang about."
        case .level:
            return "They won't say. That means it's still yours to decide. Annoying, I know."
        case .narrow:
            return "Probably not. Or not like that. Ask it smaller."
        case .shut:
            return "No. The bones don't say sorry, so I'm saying it for them."
        }
    }
}

/// What the Book remembers about spells the reader has already worked.
///
/// The cast log knows *when*. It does not know that it was raining — but a
/// worked Spell became a kept Page, and a kept Page carries the weather, the
/// hour and the kind of place it was kept in. So the recall is read back out of
/// the archive rather than stored a second time, and it can only ever say what
/// was actually recorded at the time.
enum SpellCastMemory {

    struct Working: Equatable {
        var at: Date
        var weather: String?
        var placeKind: String?
        var dayPart: String?
        /// What the reader wrote when they came back, word for word.
        var broughtBack: String? = nil
    }

    static func workings(of spellID: String, in days: [BookDay]) -> [Working] {
        let tag = "spell:\(spellID)"
        var found: [Working] = []
        for day in days {
            for page in day.pages where page.tags.contains(tag) {
                found.append(Working(
                    at: page.createdAt,
                    weather: page.context?.weatherTags.first,
                    placeKind: page.context?.placeKind,
                    dayPart: page.context?.dayPart,
                    broughtBack: page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ))
            }
        }
        return found.sorted { $0.at > $1.at }
    }

    /// One circumstance, not a list. The Book says the most particular true
    /// thing it has and stops: weather beats a place, a place beats an hour,
    /// and nothing at all is better than a guess.
    static func circumstance(of working: Working) -> String? {
        if let weather = working.weather?.nonEmpty {
            switch weather {
            case "rain": return "in the rain"
            case "snow": return "in the snow"
            case "fog": return "in the fog"
            case "storm": return "in a storm"
            case "wind": return "in the wind"
            case "frost", "cold": return "in the cold"
            case "bright": return "in full sun"
            default: return nil
            }
        }
        if let kind = working.placeKind?.nonEmpty {
            return "at \(humanisedPlace(kind))"
        }
        switch working.dayPart {
        case "night": return "at night"
        case "morning": return "first thing"
        case "evening": return "as the light went"
        default: return nil
        }
    }

    static func humanisedPlace(_ key: String) -> String {
        var out = ""
        for character in key {
            if character.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(Character(character.lowercased()))
        }
        return out
    }

    static func when(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return "earlier this month" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? "MMMM"
            : "MMMM yyyy"
        return "back in \(formatter.string(from: date))"
    }

    /// "You did this one before, in the rain, back in March."
    ///
    /// Nil when the reader has never worked it, which is most of the time and
    /// is not something to fill in.
    static func recall(
        of spellID: String,
        in days: [BookDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let worked = workings(of: spellID, in: days)
        guard let last = worked.first else { return nil }
        let moment = when(last.at, now: now, calendar: calendar)
        let where_ = circumstance(of: last).map { ", \($0)," } ?? ","
        let when_: String
        if worked.count == 1 {
            when_ = "You did this one before\(where_) \(moment)."
        } else {
            when_ = "You've done this one \(worked.count) times. The last was\(where_) \(moment)."
        }
        guard let brought = quotable(last.broughtBack, for: spellID) else { return when_ }
        return "\(when_) You came back with \u{201C}\(brought)\u{201D}"
    }

    /// The reader's own words from last time, when they are short enough to
    /// say back in one breath. Never for a signed spell: those answers are a
    /// stamp ("Said it."), and the ones that matter there were secrets.
    static func quotable(_ text: String?, for spellID: String) -> String? {
        guard let text = text?.nonEmpty,
              SpellRegistry.spell(id: spellID)?.mechanic != .countersign else { return nil }
        let line = text.components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty, line.count <= 80 else { return nil }
        let ends = line.last.map { ".!?".contains($0) } ?? false
        return ends ? line : line + "."
    }
}

// MARK: - The Gazetteer

/// One of the reader's own places, as the shelf prints it.
///
/// Phase 6 of `docs/correspondences-plan.md`. Anchors already hold everything
/// this needs — the reader's own name for the place, the weather and season it
/// was made under, how many times they have come back — and every kept Page
/// already records which Anchor it happened near. None of it was reachable
/// unless the reader was physically standing within two hundred metres. This is
/// the shelf for remembering a place you are not at.
struct GazetteerEntry: Identifiable, Equatable {
    var id: String
    /// The reader's own name for it. Always safe to print: they chose it.
    var name: String
    /// What Maps called it, and where, when the reader let the Book say so.
    var kindLine: String?
    /// The weather and season it was anchored under.
    var madeLine: String?
    /// How often they have been back.
    var returnsLine: String?
    /// What the Book has kept here, most recent first.
    var happenings: [String]
    var keptCount: Int
    /// The chart of this place, decided here so the view never makes a privacy
    /// call of its own. Nil when the Anchor's coordinates are unusable.
    var plate: MapPlateSpec?
}

enum Gazetteer {

    /// The reader's places, the ones they have been back to most first.
    static func entries(
        anchors: [AnchorRecord],
        days: [BookDay],
        happeningsPerPlace: Int = 3
    ) -> [GazetteerEntry] {
        guard !anchors.isEmpty else { return [] }

        // Every kept Page already knows which Anchor it happened near, so a
        // place's history is a query rather than a second ledger that can drift.
        var kept: [String: [BookPage]] = [:]
        for day in days {
            for page in day.pages {
                guard let anchorID = page.context?.nearbyAnchorID?.nonEmpty else { continue }
                kept[anchorID, default: []].append(page)
            }
        }

        var entries: [GazetteerEntry] = []
        for anchor in anchors {
            let pages = (kept[anchor.id] ?? []).sorted { $0.createdAt > $1.createdAt }
            // Where the reader's own Pages fall around the place, for the plate
            // to draw. Only Pages that recorded a coordinate have one.
            let placed: [AtlasMark] = pages.compactMap { page in
                guard let latitude = page.context?.latitude,
                      let longitude = page.context?.longitude else { return nil }
                return AtlasMark(
                    id: page.id, layer: .kept, latitude: latitude, longitude: longitude,
                    title: "", subtitle: nil, glyph: "circle.fill", detail: [], weight: 1
                )
            }
            entries.append(GazetteerEntry(
                id: anchor.id,
                name: anchor.name,
                kindLine: kindLine(for: anchor),
                madeLine: madeLine(for: anchor),
                returnsLine: returnsLine(for: anchor),
                happenings: pages.prefix(happeningsPerPlace).compactMap(happening),
                keptCount: pages.count,
                plate: MapPlate.spec(for: anchor, kept: placed)
            ))
        }
        return entries.sorted { left, right in
            left.keptCount == right.keptCount ? left.name < right.name : left.keptCount > right.keptCount
        }
    }

    /// What it is, and where — but only as far as the reader allowed.
    ///
    /// `usesRealNameInStory` is the reader's own decision about whether the Book
    /// may say what a place is really called. A veiled Anchor keeps its category
    /// and loses its name and its town.
    static func kindLine(for anchor: AnchorRecord) -> String? {
        guard let place = anchor.place else { return nil }
        let category = place.category.nonEmpty
        guard place.usesRealNameInStory else {
            return category.map { "A \($0)." }
        }
        let town = place.locality.nonEmpty
        switch (category, town) {
        case let (category?, town?): return "\(place.name) — a \(category) in \(town)."
        case let (category?, nil): return "\(place.name) — a \(category)."
        case let (nil, town?): return "\(place.name), in \(town)."
        case (nil, nil): return "\(place.name)."
        }
    }

    static func madeLine(for anchor: AnchorRecord) -> String? {
        let season = anchor.season.nonEmpty
        let weather = anchor.weather.nonEmpty
        switch (season, weather) {
        case let (season?, weather?): return "You anchored this in \(season), and it was \(weather.lowercased())."
        case let (season?, nil): return "You anchored this in \(season)."
        case let (nil, weather?): return "You anchored this when it was \(weather.lowercased())."
        case (nil, nil): return nil
        }
    }

    /// The Book counts returns rather than visits, because the first time was
    /// not a return and saying "one visit" of a place you made is silly.
    static func returnsLine(for anchor: AnchorRecord) -> String? {
        let returns = max(0, anchor.visitCount - 1)
        switch returns {
        case 0: return nil
        case 1: return "You've been back once."
        default: return "You've been back \(returns) times."
        }
    }

    /// One line for something the reader kept here. Their own words if they
    /// wrote any, and otherwise what the Page was — never the Book's own prose
    /// dressed up as a memory of the place.
    static func happening(_ page: BookPage) -> String? {
        if let written = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return written.count > 160 ? String(written.prefix(157)) + "…" : written
        }
        return page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    /// The Contents line. No count: that line is redrawn on every desk build.
    static let contentsDetail = "The places you've named, and what happened at them."
}
