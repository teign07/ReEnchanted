import Foundation

// The Quillquarium's oldest lore made real: writing instruments swim the air
// like fish until the right one chooses the right student. The chosen quill
// is deliberately the reader's opposite — where the hand is shy the nib is
// bold, where the hand runs loose the nib keeps rules — because an
// instrument's job is to carry the writer where they would not go alone.
// Everything here is deterministic: the same archive always mints the same
// quill, so the choosing can be re-offered across sessions without the
// candidate changing its mind.

/// What the Book has actually observed about the reader's hand, measured
/// from kept prose pages. All rates are plain averages so the profile stays
/// explainable — every temperament claim the quill makes can be traced to
/// one of these numbers.
struct ReaderMannerProfile: Equatable {
    var pageCount: Int
    /// Hedge words ("maybe", "sort of", "I think") per page.
    var hedgeRate: Double
    /// Fraction of pages that ask at least one question.
    var questionRate: Double
    /// Fraction of pages with at least one exclamation.
    var exclaimRate: Double
    /// Mean words per page.
    var averageWords: Double
    /// Fraction of pages that end on terminal punctuation.
    var punctuationDiscipline: Double

    static let hedgeTerms: [String] = [
        "maybe", "perhaps", "i think", "i guess", "sort of", "kind of",
        "probably", "possibly", "a little", "not sure", "might"
    ]

    static func eligiblePages(from pages: [BookPage]) -> [BookPage] {
        pages.filter { page in
            guard !EditionCurator.defaultPrivateTypes.contains(page.type) else { return false }
            let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count >= 3
        }
    }

    static func measure(pages: [BookPage]) -> ReaderMannerProfile {
        let prose = eligiblePages(from: pages)
            .map { $0.userInput.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !prose.isEmpty else {
            return ReaderMannerProfile(pageCount: 0, hedgeRate: 0, questionRate: 0,
                                       exclaimRate: 0, averageWords: 0, punctuationDiscipline: 0)
        }
        var hedges = 0
        var questions = 0
        var exclaims = 0
        var words = 0
        var punctuated = 0
        for text in prose {
            let lowered = text.lowercased()
            hedges += Self.hedgeTerms.reduce(0) { count, term in
                count + lowered.components(separatedBy: term).count - 1
            }
            if text.contains("?") { questions += 1 }
            if text.contains("!") { exclaims += 1 }
            words += text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            if let last = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"')")).last,
               ".!?".contains(last) {
                punctuated += 1
            }
        }
        let count = Double(prose.count)
        return ReaderMannerProfile(
            pageCount: prose.count,
            hedgeRate: Double(hedges) / count,
            questionRate: Double(questions) / count,
            exclaimRate: Double(exclaims) / count,
            averageWords: Double(words) / count,
            punctuationDiscipline: Double(punctuated) / count
        )
    }
}

/// The quill's nature, expressed as inverted axes: each one records what the
/// Book saw in the reader's hand and the opposite the quill therefore brings.
struct QuillTemperament: Codable, Equatable {
    struct Axis: Codable, Equatable {
        /// "boldness", "order", "inquiry", or "ornament".
        var id: String
        /// Which half of the axis the reader occupies (bold, orderly,
        /// questioning, expansive are the "high" sides). The quill always
        /// stands on the other half.
        var readerSideIsHigh: Bool
        /// The reader's observed side, phrased for prose ("hedges in soft maybes").
        var readerLeaning: String
        /// The quill's opposing side ("does not believe in maybe").
        var quillLeaning: String
        /// How pronounced the reader's side was, 0...1.
        var strength: Double
    }

    var axes: [Axis]

    var dominant: Axis? { axes.max { ($0.strength, $1.id) < ($1.strength, $0.id) } }
    var strongestTwo: [Axis] {
        Array(axes.sorted { ($0.strength, $1.id) > ($1.strength, $0.id) }.prefix(2))
    }

    /// Builds the four inverted axes from an observed profile. Neutral
    /// readings still pick a side (the quill must have a personality on day
    /// one) but carry low strength, so prose leans on the axes with real
    /// evidence behind them.
    static func opposing(_ profile: ReaderMannerProfile) -> QuillTemperament {
        func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }

        // 0 = tentative reader, 1 = bold reader.
        let boldMeasure = clamp01(0.5 + profile.exclaimRate - profile.hedgeRate * 1.4)
        // 0 = loose hand, 1 = orderly hand.
        let orderMeasure = clamp01(profile.punctuationDiscipline)
        // 0 = declaring reader, 1 = questioning reader.
        let inquiryMeasure = clamp01(profile.questionRate * 2.2)
        // 0 = terse reader, 1 = expansive reader.
        let ornamentMeasure = clamp01(profile.averageWords / 36)

        func axis(_ id: String, measure: Double,
                  lowReader: String, lowQuill: String,
                  highReader: String, highQuill: String) -> Axis {
            let readerIsHigh = measure >= 0.5
            return Axis(
                id: id,
                readerSideIsHigh: readerIsHigh,
                readerLeaning: readerIsHigh ? highReader : lowReader,
                quillLeaning: readerIsHigh ? highQuill : lowQuill,
                strength: clamp01(abs(measure - 0.5) * 2)
            )
        }

        return QuillTemperament(axes: [
            axis("boldness", measure: boldMeasure,
                 lowReader: "writes in pencil-soft maybes",
                 lowQuill: "is bold to the point of rudeness and does not believe in maybe",
                 highReader: "writes at full volume, exclamation-first",
                 highQuill: "is quiet and exact, and waits for the one word that needs no emphasis"),
            axis("order", measure: orderMeasure,
                 lowReader: "lets sentences run loose and unfenced",
                 lowQuill: "keeps strict margins and believes a comma is a promise",
                 highReader: "keeps every line squared and properly closed",
                 highQuill: "is wayward, and wants to know what happens if the rule bends just once"),
            axis("inquiry", measure: inquiryMeasure,
                 lowReader: "states things plainly and moves on",
                 lowQuill: "answers every statement with one more good question",
                 highReader: "asks the page more questions than it answers",
                 highQuill: "declares, flatly and often, and expects the page to keep up"),
            axis("ornament", measure: ornamentMeasure,
                 lowReader: "spends words like they are rationed",
                 lowQuill: "is incurably ornate and flourishes its descenders when nobody is watching",
                 highReader: "writes long and lets the words breathe",
                 highQuill: "is plain-spoken and takes the ribbons off any sentence standing on a chair")
        ])
    }
}

/// The instrument that chose the reader. Minted once, kept for good; the
/// display name is how story prose refers to it.
struct ChosenQuill: Codable, Equatable {
    var id: String
    var name: String
    var make: String
    var temperament: QuillTemperament
    var wants: [String]
    var quirks: [String]
    var chosenAt: Date

    var displayName: String { "\(name) (\(make))" }

    /// A one-line temperament summary in the Book's voice, built from the two
    /// axes with the strongest evidence.
    var natureLine: String {
        let pair = temperament.strongestTwo
        guard let first = pair.first else { return "\(name) has opinions, and ink to spend on them." }
        if pair.count == 2 {
            return "You \(first.readerLeaning); \(name) \(first.quillLeaning). You \(pair[1].readerLeaning); it \(pair[1].quillLeaning)."
        }
        return "You \(first.readerLeaning); \(name) \(first.quillLeaning)."
    }

    /// One-word temperament traits for the quill's side of each axis.
    var traitWords: [String] {
        temperament.strongestTwo.map { axis in
            switch (axis.id, axis.readerSideIsHigh) {
            case ("boldness", false): return "bold"
            case ("boldness", true): return "quiet-exact"
            case ("order", false): return "strict"
            case ("order", true): return "wayward"
            case ("inquiry", false): return "questioning"
            case ("inquiry", true): return "declaring"
            case ("ornament", false): return "ornate"
            default: return "plain-spoken"
            }
        }
    }

    /// The quill's standing entry in the Cast. An instrument is a full cast
    /// member here — in ReEnchanted, magic is worked through pens and quills,
    /// never wands, and the implements have their own opinions. The id is
    /// derived from the quill's own, so adoption can upsert without minting
    /// twins.
    func castMember(now: Date = Date()) -> CustomCastMember {
        CustomCastMember(
            id: "user-cast-\(id)",
            name: name,
            kind: .character,
            meaning: "The instrument that chose its writer in the Quillquarium",
            description: "\(make.prefix(1).uppercased() + make.dropFirst()). \(natureLine) It also \(quirks.first ?? "hums faintly on downstrokes").",
            traits: traitWords,
            beliefs: [
                "the right instrument can choose the hand as much as the hand chooses the instrument",
                "magic is written, not waved"
            ],
            goals: wants,
            tags: ["custom-cast", "chosen-quill", "quill", "instrument", "quillquarium", "companion"],
            baseBelief: 30,
            narrativeWeight: 22,
            createdAt: now,
            updatedAt: now,
            imageAsset: nil
        )
    }
}

enum QuillChoosing {
    static let chosenTag = "quill-chosen"
    static let metadataKey = "chosenQuill"
    /// Enough prose pages to read a hand honestly before an instrument
    /// commits to opposing it.
    static let minimumProsePages = 6
    static let minimumChoosingProsePages = 10
    static let minimumProseDays = 4
    static let minimumDaysSinceFirstProse = 5

    static func hasMatureHand(
        _ pages: [BookPage],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let prosePages = ReaderMannerProfile.eligiblePages(from: pages)
        guard prosePages.count >= minimumChoosingProsePages else { return false }
        let proseDays = Set(prosePages.map { BookDay.id(for: $0.createdAt, calendar: calendar) })
        guard proseDays.count >= minimumProseDays,
              let first = prosePages.map(\.createdAt).min() else { return false }
        let age = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: first),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return age >= minimumDaysSinceFirstProse
    }

    static let names: [String] = [
        "Vesper", "Meridian", "Bellwether", "Quince", "Ombra", "Petrel",
        "Wick", "Norrow", "Greywing", "Juniper", "Halcyon", "Sable",
        "Thistle", "Cobalt"
    ]

    static let makes: [String] = [
        "a heron-feather quill with a left-leaning curve",
        "a brass-nibbed dip pen",
        "a glass pen the colour of pond ice",
        "a crow quill cut for small hands",
        "a fountain pen that survived a decade in somebody's coat pocket",
        "a goose quill with one stubborn barb",
        "a reed pen from the Labyrinth's own windowsill garden",
        "a carpenter's pencil sharpened with a knife, honorary quill by special petition"
    ]

    static let sharedQuirks: [String] = [
        "sulks nib-down in the inkwell when ignored",
        "hums faintly on downstrokes",
        "refuses on principle to write the word \"very\"",
        "drinks more ink on rainy days",
        "sleeps in the spine of whatever book is nearest",
        "practices signatures it has no right to"
    ]

    /// The quill's want for an axis: always the opposite side of wherever the
    /// reader stands.
    static func want(for axis: QuillTemperament.Axis) -> String {
        switch (axis.id, axis.readerSideIsHigh) {
        case ("boldness", false):
            return "wants the daring version of every sentence written first, so the timid version can be chosen honestly"
        case ("boldness", true):
            return "wants one sentence per page slowed down until it is exactly true"
        case ("order", true):
            return "wants to know what happens if the rule is broken just once, for science"
        case ("order", false):
            return "wants the margins straight and the commas kept like promises"
        case ("inquiry", true):
            return "wants questions answered on the same page they were asked"
        case ("inquiry", false):
            return "wants every certainty to survive one good question before it is inked"
        case ("ornament", false):
            return "wants a flourish on the descenders whenever nobody is watching"
        default:
            return "wants the plain word restored wherever a fancy one is standing on its chair"
        }
    }

    /// Deterministically mints the quill this archive would choose. The seed
    /// comes from the earliest kept page so re-offering the ceremony across
    /// days never changes which instrument is waiting.
    static func mint(from pages: [BookPage], now: Date = Date()) -> ChosenQuill? {
        let profile = ReaderMannerProfile.measure(pages: pages)
        guard profile.pageCount >= minimumProsePages else { return nil }
        let anchor = pages.min { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        let seed = abs("quill-of-\(anchor?.id ?? "unwritten")".stableHash)
        let temperament = QuillTemperament.opposing(profile)
        let name = names[seed % names.count]
        let make = makes[(seed / names.count) % makes.count]
        let leaningWants = temperament.strongestTwo.map(want(for:))
        let quirk = sharedQuirks[(seed / (names.count * makes.count)) % sharedQuirks.count]
        return ChosenQuill(
            id: "quill-\(name.lowercased())-\(seed % 997)",
            name: name,
            make: make,
            temperament: temperament,
            wants: leaningWants,
            quirks: [quirk],
            chosenAt: now
        )
    }

    /// The ceremony page's prose: the Quillquarium scene, the landing, and the
    /// opposite-nature explained through what the Book actually observed.
    static func choosingBody(quill: ChosenQuill) -> String {
        let dominant = quill.temperament.dominant
        let evidence = dominant.map {
            "It had read your hand and noticed that \(pastReaderObservation(for: $0)). It had applied for the post especially because of that."
        } ?? "It had read your hand and applied for the post anyway."
        let counterweight = dominant.map {
            "Where your hand \(pastReaderHabit(for: $0)), the new instrument \(pastQuillPromise(for: $0))."
        } ?? "The new instrument had arrived with opinions, and ink to spend on them."
        return """
        The Quillquarium had not been still when you entered. Pens had schooled overhead like minnows, their nibs glinting; predatory quills had patrolled the high shelves; somewhere, a pencil had pretended badly to be asleep. Instruments sometimes waited there for years, the keepers had told you, because a pen could not merely be picked up. It had to choose.

        That night, one of them chose you.

        On your second breath in the room, it had broken from the school above you. It had circled once — checking your margins, the keepers later said, the way sailors checked weather — and landed on the desk before you with its nib politely lowered. Its name was \(quill.name). It was \(quill.make). \(evidence)

        \(counterweight)

        That had not been an insult. It had been the oldest rule of the room: the right instrument was the one that carried you where you would not have gone alone. \(quill.name) had chosen you because it \(quill.wants.first ?? "had opinions, and ink to spend on them"). For the record, it also \(quill.quirks.first ?? "hummed faintly on downstrokes").

        The page waited for your answer. If you kept it, the choosing would stand, and \(quill.name) would ride in your Book's spine with opinions about everything the two of you wrote. If you let it wait, the quill would return to the school without offense. Quills had always been patient. This one had already decided about you.
        """
    }

    private static func pastReaderObservation(for axis: QuillTemperament.Axis) -> String {
        switch (axis.id, axis.readerSideIsHigh) {
        case ("boldness", false): return "you had often softened a thought with maybe"
        case ("boldness", true): return "you had often sent a sentence out at full volume"
        case ("order", false): return "you had let sentences roam past their fences"
        case ("order", true): return "you had kept each line squared and properly closed"
        case ("inquiry", false): return "you had stated what you meant and moved on"
        case ("inquiry", true): return "you had asked the page more questions than it answered"
        case ("ornament", false): return "you had spent words as though they were rationed"
        default: return "you had given your sentences room to wander"
        }
    }

    private static func pastReaderHabit(for axis: QuillTemperament.Axis) -> String {
        switch (axis.id, axis.readerSideIsHigh) {
        case ("boldness", false): return "had hesitated"
        case ("boldness", true): return "had rushed ahead"
        case ("order", false): return "had wandered"
        case ("order", true): return "had obeyed every margin"
        case ("inquiry", false): return "had declared"
        case ("inquiry", true): return "had questioned"
        case ("ornament", false): return "had stayed spare"
        default: return "had grown elaborate"
        }
    }

    private static func pastQuillPromise(for axis: QuillTemperament.Axis) -> String {
        switch (axis.id, axis.readerSideIsHigh) {
        case ("boldness", false): return "had arrived to be brave first"
        case ("boldness", true): return "had arrived to slow one true word down"
        case ("order", false): return "had arrived to keep commas like promises"
        case ("order", true): return "had arrived to bend one rule and see what escaped"
        case ("inquiry", false): return "had arrived with one more good question"
        case ("inquiry", true): return "had arrived prepared to answer plainly"
        case ("ornament", false): return "had arrived with flourishes to spare"
        default: return "had arrived to take the ribbons off the truth"
        }
    }

    /// Gemma prose is allowed onto the choosing page only when it still names
    /// the minted instrument, stays in the Quillquarium ceremony, addresses
    /// the reader as "you", and carries unmistakable past-tense narration.
    /// A failed check falls back to `choosingBody`, so an off-topic or
    /// first-person model turn can never replace the actual choosing again.
    static func generatedCeremonyIsGrounded(_ prose: String, quill: ChosenQuill) -> Bool {
        let trimmed = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 180 else { return false }
        let lower = " \(trimmed.lowercased()) "
        guard lower.contains(quill.name.lowercased()),
              lower.contains(" you ") || lower.contains(" your "),
              lower.contains("quillquarium") || lower.contains(" quill ") || lower.contains(" nib "),
              lower.contains(" chose ") || lower.contains(" chosen ") || lower.contains(" choosing ") else {
            return false
        }
        let pastMarkers = [" was ", " were ", " had ", " chose ", " landed ", " circled ", " waited "]
        guard pastMarkers.filter({ lower.contains($0) }).count >= 2 else { return false }

        // Reject an unmistakable first-person narrator. Dialogue may still use
        // "I", so only paragraph openings are treated as a narration failure.
        let paragraphs = trimmed.components(separatedBy: "\n\n")
        return !paragraphs.contains { paragraph in
            let line = paragraph.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return line.hasPrefix("i ") || line.hasPrefix("i'd ") || line.hasPrefix("i had ") || line.hasPrefix("my ")
        }
    }

    /// A dedicated handoff for the once-ever choosing. Keeping this beside
    /// the minting lore prevents the ceremony from silently drifting back
    /// through the generic two-cast relationship prompt.
    static func generationPrompt(surface: SurfacePage) -> String {
        let metadata = surface.payload.metadata
        let quill: ChosenQuill? = metadata[metadataKey]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(ChosenQuill.self, from: $0) }
        let name = quill?.name ?? metadata["quillName"] ?? "the waiting quill"
        let make = quill?.make ?? metadata["quillMake"] ?? "a living writing instrument"
        let nature = quill?.natureLine ?? metadata["quillNature"] ?? "The instrument was the useful opposite of the reader's hand."
        let wants = quill?.wants.joined(separator: "; ") ?? metadata["quillWant"] ?? "to carry the writer somewhere new"
        let quirks = quill?.quirks.joined(separator: "; ") ?? metadata["quillQuirk"] ?? "hummed on downstrokes"

        return """
        You were the scribe of the Labyrinth of Stories inside ReEnchanted, writing the once-ever ceremony called "The Pen Choosing."

        CANON:
        - Magic here was written, never waved. There were no wands.
        - In the Quillquarium, living pens, pencils, and quills schooled through the air until an instrument chose its writer.
        - The right instrument chose the writer whose habits it could usefully oppose. It was a companion and counterweight, not a pet, wand, or generic cast member.
        - This exact instrument was \(name): \(make).
        - What the Book had learned about the pairing: \(nature)
        - What \(name) wanted: \(wants)
        - Its private oddity: \(quirks)

        THE CEREMONY FACTS TO STAGE:
        \(surface.payload.body)

        NON-NEGOTIABLE VOICE AND SHAPE:
        - Write the entire scene in SECOND-PERSON PAST TENSE: "you entered," "you heard," "the quill had waited." Address the reader only as "you."
        - Never use first-person narration. Never narrate as "I" or "we." Dialogue may use first person only when a keeper speaks.
        - Keep the entire scene about \(name) breaking from the airborne school, studying the reader's hand, landing before them, and choosing them in the Quillquarium.
        - Make the choosing tactile and magical: airborne instruments, ink, paper, sound, the weight or temperature of the chosen pen, and one small reaction from the room.
        - Explain through action why this opposite temperament made the pairing right. Do not diagnose the reader or invent private facts beyond the supplied writing habits.
        - Do not introduce two cast members, a Loom milestone, a relationship scene, today's weather, or an unrelated adventure.
        - Do not claim the reader accepted. End at the held-breath choice: keeping the page would make the choosing stand; letting it wait would return \(name) patiently to the school.
        - Prose only. No headings, lists, analysis, or meta-commentary. 5 to 7 short paragraphs.
        """
    }

    /// The prompt-side directive that lets the quill tug at story generation.
    /// One clause of prose and one leaning choice — an instrument with
    /// opinions, never a narrator.
    static func storyDirective(for quill: ChosenQuill) -> String {
        let push = quill.temperament.dominant?.quillLeaning ?? "has opinions"
        return """
        THE CHOSEN QUILL:
        This page is being written with \(quill.displayName), the instrument that chose the reader in the Quillquarium. \(quill.natureLine)
        Let the quill's leaning show exactly once: one clause of prose may notice the pen pulling, and one of the three choices should lean the way the quill would push — it \(push). The quill is an instrument with opinions, never a narrator and never a speaking character.
        """
    }

    // MARK: - Margin voice

    /// Roughly one eligible keep in five gets the quill's voice instead of a
    /// cast note — present enough to feel alive, rare enough to stay a treat.
    static func marginNote(
        quill: ChosenQuill, for input: String, pageType: BookPageType, pageID: String
    ) -> KeepMarginalia.Note? {
        guard KeepMarginalia.isEligible(input: input, pageType: pageType) else { return nil }
        let seed = abs("quill-margin-\(pageID)".stableHash)
        guard seed % 5 == 0 else { return nil }
        let lines = marginLines(for: quill)
        var line = lines[(seed / 5) % lines.count]
        if line.contains("{word}") {
            guard let word = notableWord(in: input) else { return nil }
            line = line.replacingOccurrences(of: "{word}", with: word)
        }
        return KeepMarginalia.Note(
            castSlug: "chosen-quill",
            castName: quill.name,
            assetName: "LabyrinthLocationQuillquarium",
            line: line
        )
    }

    static func marginLines(for quill: ChosenQuill) -> [String] {
        var lines = [
            "I inked that one a shade darker than you asked. It could take it.",
            "Noted, filed, and privately annotated. You'll find my footnote eventually.",
            "That page drank the ink like it was thirsty. Good sign."
        ]
        for axis in quill.temperament.strongestTwo {
            switch (axis.id, axis.readerSideIsHigh) {
            case ("boldness", false):
                lines += [
                    "I underlined \"{word}\" before you finished writing it. One of us has to be brave first.",
                    "Next time we write that thought at full volume. I'll bring the ink."
                ]
            case ("boldness", true):
                lines += [
                    "I slowed you down on \"{word}\". It deserved the extra half-second.",
                    "No flourish tonight. That sentence was already wearing its best coat."
                ]
            case ("order", false):
                lines += ["I straightened two commas while you weren't looking. You're welcome."]
            case ("order", true):
                lines += ["I let your margins wander today. They came back with souvenirs."]
            case ("inquiry", false):
                lines += ["Are you sure about \"{word}\"? I inked it anyway. But are you?"]
            case ("inquiry", true):
                lines += ["You asked the page a question. I answered it in the gutter, where answers keep."]
            case ("ornament", false):
                lines += ["I gave \"{word}\" a flourish. It had earned one."]
            default:
                lines += ["I took the ribbons off one sentence. It stands up straighter now."]
            }
        }
        return lines
    }

    static func notableWord(in input: String) -> String? {
        input.split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count >= 5 }
            .max { ($0.count, $1.lowercased()) < ($1.count, $0.lowercased()) }
    }
}

struct QuillChoosingPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSource(
        id: "quillquarium-choosing",
        type: .castBond,
        title: "The Quill Chooses the Writer",
        shortTitle: "Chosen Quill",
        symbolName: "pencil.and.scribble",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "once, after the Book has read enough of the reader's hand",
        note: "An opposing writing instrument chooses the reader in the Quillquarium."
    )

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              inputs.chosenQuill == nil else { return [] }
        // The choosing claims to have read the reader's hand, so it waits for
        // the same maturity as the other pages that make that claim.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        // On a hard day the Book leads with care. This milestone is once-ever
        // and self-suppressing, so it simply waits for a calmer session.
        guard !context.distress.isActive else { return [] }
        let pages = (inputs.days + [day]).flatMap(\.capturedPages)
        guard QuillChoosing.hasMatureHand(pages, now: now),
              !pages.contains(where: { $0.tags.contains(QuillChoosing.chosenTag) }),
              let quill = QuillChoosing.mint(from: pages, now: now),
              let data = try? JSONEncoder().encode(quill),
              let encoded = String(data: data, encoding: .utf8) else { return [] }
        return [SurfacePage(
            id: "\(source.id)-\(quill.id)",
            type: .castBond,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            // A once-ever companion milestone: above the ordinary reflective
            // moments, a step under First Reading's 80 so the proof-of-reading
            // page keeps the earliest slot when both are waiting.
            score: 76,
            reason: "The Book has enough real pages to read the reader's hand, and one patient instrument has chosen.",
            prompt: "A quill has broken from the school overhead.",
            detail: "\(quill.name), \(quill.make), has chosen the reader it can disagree with usefully.",
            payload: BookPagePayload(
                headline: "The Quill Chooses the Writer",
                body: QuillChoosing.choosingBody(quill: quill),
                metadata: [
                    "source": source.id,
                    QuillChoosing.metadataKey: encoded,
                    "quillName": quill.name,
                    "quillID": quill.id,
                    "quillMake": quill.make,
                    "quillNature": quill.natureLine,
                    "quillWant": quill.wants.first ?? "has opinions, and ink to spend on them",
                    "quillQuirk": quill.quirks.first ?? "hums faintly on downstrokes",
                    "pageTitle": "The Pen Choosing",
                    "pageSymbol": "pencil.and.scribble",
                    "locationAsset": "LabyrinthLocationQuillquarium",
                    "milestone": "true",
                    // If the reader neither keeps nor deliberately dismisses
                    // the choosing, the ceremony goes dormant instead of
                    // becoming furniture on every later desk.
                    "automaticRepeatRestDays": "90",
                    "noveltyKey": "choosing-\(quill.id)",
                    "tags": "\(QuillChoosing.chosenTag),quillquarium,chosen-quill"
                ]
            )
        )]
    }
}
