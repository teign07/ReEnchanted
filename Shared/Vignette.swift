import Foundation

// MARK: - Vignettes
//
// A Story Page is a vignette: one short scene in the Labyrinth that stops at a
// decision. The recipe says what the scene is about; this file says what
// happens in it.
//
// Measured on the Mac lab (real Gemma E2B, 2026-11-01, 22 recipes × 2): the old
// brief handed Gemma three full character sheets, a genre sample, the dramatic
// contract and every directive at once (about 2,200 prompt tokens) and asked it
// to invent the scene's events. A 2B model renders well and invents badly, so
// it wrote atmosphere: "the air thickened", characters narrating their brief
// ("He wanted the precise thing"), Cast members who weren't in the scene, and
// cadence examples pasted in as dialogue. Nothing happened, and no scene ended
// at its decision.
//
// So the skeleton now carries the events. A shape is an ordered beat sheet
// for the recipe's scene mode; the recipe's own pool of happenings supplies
// two concrete things that go wrong or go strange; each speaker gets one voice
// line and one habit instead of a whole sheet. Gemma tells what the plan says
// happens, in one call of about 400 prompt tokens.
//
// Beats are written as facts, never as orders: the model pastes orders into
// the story ("Stop before anything is decided." arrived verbatim in v1).

struct VignetteShape: Equatable {
    var id: String
    var mode: StoryRecipeSceneMode
    /// Templates over `{{premise}}`, `{{lead}}`, `{{companion}}`, `{{first}}`,
    /// `{{second}}` and `{{aside}}`.
    var beats: [String]
}

enum VignetteShapes {
    static let all: [VignetteShape] = [
        VignetteShape(id: "already-running", mode: .action, beats: [
            "It has already started. {{premise}} {{lead}} shouts to you, \"<their words>\"",
            "{{first}}",
            "{{second}} {{aside}}"
        ]),
        VignetteShape(id: "the-plan", mode: .action, beats: [
            "{{premise}} {{lead}} explains the plan to you: \"<their words>\"",
            "The plan is working, and then: {{first}}",
            "{{second}} {{aside}}"
        ]),
        VignetteShape(id: "the-ask", mode: .conversation, beats: [
            "{{lead}} and {{companion}} are already talking when you arrive. {{premise}} {{lead}} says, \"<their words>\"",
            "{{companion}} answers, \"<their words>\" Meanwhile: {{first}}",
            "{{second}} {{lead}} says, \"<their words>\" {{companion}} says, \"<their words>\""
        ]),
        VignetteShape(id: "the-argument", mode: .conversation, beats: [
            "{{lead}} and {{companion}} are halfway through an argument. {{premise}} {{lead}} says, \"<their words>\"",
            "{{first}} {{companion}} says, \"<their words>\"",
            "{{second}} {{lead}} says, \"<their words>\""
        ]),
        VignetteShape(id: "the-room-misbehaves", mode: .environmental, beats: [
            "{{premise}} {{lead}} says, \"<their words>\"",
            "{{lead}} tries something ordinary. {{first}}",
            "{{second}} {{aside}}"
        ]),
        VignetteShape(id: "the-arrival", mode: .environmental, beats: [
            "You come round the corner with {{lead}} and find it. {{premise}} {{lead}} says, \"<their words>\"",
            "{{lead}} goes closer. {{first}}",
            "{{second}} {{aside}}"
        ]),
        VignetteShape(id: "the-deadline", mode: .balanced, beats: [
            "{{premise}} {{lead}} tells you, \"<their words>\"",
            "Work starts. {{first}}",
            "{{second}} {{aside}}"
        ]),
        VignetteShape(id: "the-visitor", mode: .balanced, beats: [
            "{{premise}} {{companion}} turns up and says, \"<their words>\"",
            "They try to carry on. {{first}}",
            "{{second}} {{lead}} says, \"<their words>\""
        ])
    ]

    /// The last beat: the scene stops at its decision, named as the buttons
    /// name it. An open "<a short question>" slot came back as "Serenity asks
    /// a short question for you." or "Do you feel the weight of this moment?"
    static let stands = [
        "Nothing is decided yet. {{lead}} asks you which it should be: {{options}}?",
        "Everyone looks at you. {{lead}} asks you: {{options}}?",
        "{{lead}} turns to you and asks what to do: {{options}}?"
    ]

    /// Speech is a slot to fill, not a cue to copy. Told "Wicker has something
    /// to say about that", the model wrote exactly that and moved on.
    static let speechSlot = "<their words>"

    static func shapes(for mode: StoryRecipeSceneMode, hasCompanion: Bool) -> [VignetteShape] {
        let matching = all.filter { $0.mode == mode }
        guard !hasCompanion else { return matching }
        // A shape that stages two people can't be told with one.
        let solo = matching.filter { shape in !shape.beats.joined().contains("{{companion}}") }
        return solo.isEmpty ? all.filter { $0.mode == .environmental } : solo
    }
}

/// What the recipe brings to the skeleton: its own room, the things that can
/// happen there, and (for recipes that never authored them) its decisions.
struct VignetteParts: Equatable {
    var place: String
    /// Replaces a templated premise that only made sense with the reader's
    /// whole Page pasted in. May use `{{thing}}`.
    var premise: String? = nil
    var happenings: [String]
    var decisions: [StoryRecipeDecisionTemplate]? = nil
}

struct VignetteSpeaker: Codable, Equatable {
    /// How the page names them: titled staff by surname, students by first name.
    var name: String
    var pronoun: String?
    var register: String
    var habit: String
}

struct VignettePlan: Codable, Equatable {
    static let metadataKey = "storyVignettePlan"

    var recipeID: String
    var shapeID: String
    var place: String
    var lead: VignetteSpeaker
    var companion: VignetteSpeaker?
    var hour: String?
    var mood: String
    /// The reader's own kept words, exactly, when the recipe remembers a Page.
    var keptWords: String?
    var beats: [String]
    var happenings: [String]

    var encodedMetadata: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    static func decode(metadata: String?) -> VignettePlan? {
        guard let data = metadata?.data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(VignettePlan.self, from: data)
    }
}

enum VignettePlanBuilder {
    static func plan(
        recipe: StoryRecipe,
        premise: String,
        tone: String,
        lead: NarrativeWorldEntity,
        companion: NarrativeWorldEntity?,
        grounding: StoryGrounding,
        thing: String,
        decisions: [StoryRecipeDecisionTemplate]?,
        slotKey: String
    ) -> VignettePlan? {
        let parts = parts(for: recipe)
        let happenings = (parts?.happenings ?? []).map { fill($0, lead: lead, companion: companion, thing: thing) }
        guard happenings.count >= 2 else { return nil }
        let seed = abs("\(slotKey)-\(recipe.id)-vignette".stableHash)
        let first = seed % happenings.count
        let second = (first + 1 + (seed / 7) % (happenings.count - 1)) % happenings.count
        let shapes = VignetteShapes.shapes(for: recipe.sceneMode, hasCompanion: companion != nil)
        let shape = shapes[(seed / 13) % shapes.count]
        let leadName = pageName(lead)
        let companionName = companion.map(pageName)
        let premiseText = secondPerson(fill(parts?.premise ?? premise, lead: lead, companion: companion, thing: thing))
        let aside = companionName.map { "\($0) says, \"\(VignetteShapes.speechSlot)\"" } ?? ""
        let options = StoryChoiceRole.allCases
            .compactMap { role in decisions?.first { $0.role == role }?.actionTemplate }
            .map { fill($0, lead: lead, companion: companion, thing: thing) }
            .map { $0.prefix(1).lowercased() + $0.dropFirst() }
        let stand = options.count == 3
            ? VignetteShapes.stands[(seed / 17) % VignetteShapes.stands.count]
                .replacingOccurrences(of: "{{options}}", with: "\(options[0]), \(options[1]), or \(options[2])")
            : "Nothing is decided yet. {{lead}} asks you what to do now."
        let keptWords: String? = recipe.resolvedGroundingUse == .remembered
            && (grounding.kind == .keptPage || grounding.kind == .souvenirDoor)
            ? grounding.sceneMaterial.nonEmpty
            : nil
        // Kept words go into the story as a thing on the page, in your hand.
        // Given to a speaker, in the header or in a beat, the Cast said them as
        // their own ("Dr. Inkrest says, 'Mara didn't text back...'").
        let reading = keptWords.map { " Your words are written there, in your own handwriting: “\($0)”" } ?? ""
        var shapeBeats = shape.beats
        if !reading.isEmpty, !shapeBeats.isEmpty { shapeBeats[0] += reading }
        let beats = (shapeBeats + [stand]).map { beat in
            beat.replacingOccurrences(of: "{{premise}}", with: premiseText)
                .replacingOccurrences(of: "{{first}}", with: happenings[first])
                .replacingOccurrences(of: "{{second}}", with: happenings[second])
                .replacingOccurrences(of: "{{aside}}", with: aside)
                .replacingOccurrences(of: "{{lead}}", with: leadName)
                .replacingOccurrences(of: "{{companion}}", with: companionName ?? "")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        return VignettePlan(
            recipeID: recipe.id,
            shapeID: shape.id,
            place: parts?.place ?? recipe.place ?? "",
            lead: speaker(lead, habitSeed: seed),
            companion: companion.map { speaker($0, habitSeed: seed / 3) },
            hour: grounding.kind == .timeAndSeason ? hourLine(grounding.text) : nil,
            mood: secondPerson(tone),
            keptWords: keptWords,
            beats: beats,
            happenings: [happenings[first], happenings[second]]
        )
    }

    /// Authored parts on the recipe win, so a reader pack can bring its own;
    /// bundled recipes keep theirs in the catalogue below.
    static func parts(for recipe: StoryRecipe) -> VignetteParts? {
        let bundled = catalogue[recipe.id]
        if let happenings = recipe.happenings, happenings.count >= 2 {
            return VignetteParts(
                place: recipe.place ?? bundled?.place ?? "",
                premise: nil,
                happenings: happenings,
                decisions: nil
            )
        }
        return bundled
    }

    /// Titled staff are named by surname on the page; students and the rest by
    /// first name. The full name stays in canon and in the receipts.
    static func pageName(_ entity: NarrativeWorldEntity) -> String {
        pageName(fullName: entity.name)
    }

    static func pageName(fullName: String) -> String {
        let words = fullName.split(separator: " ").map(String.init)
        guard let first = words.first else { return fullName }
        if ["Professor", "Dr.", "Doctor", "Headmistress", "Madam"].contains(first), let last = words.last, words.count > 1 {
            return "\(first) \(last)"
        }
        return first
    }

    /// Only pronouns canon or bj has settled. Everybody else stays unpronouned
    /// in the brief rather than guessed.
    static let pronouns: [String: String] = [
        "ambrose-trencher": "he",
        "stonebrook": "he",
        "permancer": "he",
        "momort": "he",
        "villanelle": "she",
        "dr-vellum": "she",
        "euphony": "she"
    ]

    private static func speaker(_ entity: NarrativeWorldEntity, habitSeed: Int) -> VignetteSpeaker {
        let register = entity.resolvedWritingVoice.register
            .split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let habits = entity.quirks.filter { !$0.isEmpty }
        let habit = habits.isEmpty ? "" : habits[habitSeed % habits.count]
        let pronoun = pronouns.first { entity.id == $0.key || entity.id.hasSuffix($0.key) }?.value
        return VignetteSpeaker(name: pageName(entity), pronoun: pronoun, register: register, habit: habit)
    }

    private static func fill(_ text: String, lead: NarrativeWorldEntity, companion: NarrativeWorldEntity?, thing: String) -> String {
        text.replacingOccurrences(of: "{{lead}}", with: pageName(lead))
            .replacingOccurrences(of: "{{companion}}", with: companion.map(pageName) ?? "someone")
            .replacingOccurrences(of: "{{thing}}", with: thing)
            .replacingOccurrences(of: lead.name, with: pageName(lead))
            .replacingOccurrences(of: companion?.name ?? "\u{0}", with: companion.map(pageName) ?? "")
    }

    static func secondPerson(_ text: String) -> String {
        text.replacingOccurrences(of: "the reader's", with: "your")
            .replacingOccurrences(of: "The reader's", with: "Your")
            .replacingOccurrences(of: "the reader", with: "you")
            .replacingOccurrences(of: "The reader", with: "You")
    }

    private static func hourLine(_ grounding: String) -> String {
        grounding.replacingOccurrences(of: " in the player's real day", with: "")
    }
}

enum VignetteBrief {
    static let system = """
    You are a storybook telling one scene to the person reading you, so the reader is "you".
    Present tense. Tell it the way a good storyteller reads aloud: specific things, odd or funny details, and plenty of talk. People say what they think in their own way. Use "says". Don't describe how voices sound, and keep adjectives few.
    You are in the scene, but you never move, speak, touch, think or feel. Other people act, and they talk to you.
    Only the people named in the brief are in the scene.
    """

    static func prompt(for plan: VignettePlan) -> String {
        let people = [plan.lead.name, plan.companion?.name].compactMap { $0 }.joined(separator: " and ")
        var lines = ["Place: \(plan.place).", "People: \(people), and you."]
        if let hour = plan.hour { lines.append(hour) }
        for speaker in [plan.lead, plan.companion].compactMap({ $0 }) {
            let who = speaker.name + (speaker.pronoun.map { " (\($0))" } ?? "")
            // "X talks like this:" had the model describing voices ("his voice
            // like stones shifting"); a bare label doesn't.
            var line = "\(who): \(speaker.register)."
            if !speaker.habit.isEmpty {
                line += " \(speaker.name) \(speaker.habit)."
            }
            lines.append(line)
        }
        lines.append("Mood: \(plan.mood)")
        let beats = plan.beats.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        \(lines.joined(separator: "\n"))

        What happens, in order:
        \(beats)

        Tell this scene in 4 paragraphs of 60 to 90 words each. Replace every <...> with the real words.
        """
    }
}

// MARK: - The catalogue
//
// Happenings are the authored magic: small, concrete, a subject and a verb,
// funny or eerie, and never something the reader does. Two of each recipe's
// pool are dealt per vignette, so the same recipe tells differently on
// different days. Premises are replaced only where the recipe's own template
// needed the reader's whole Page to make sense.

extension VignettePlanBuilder {
    private static func decide(_ role: StoryChoiceRole, _ action: String, gain: String, cost: String) -> StoryRecipeDecisionTemplate {
        StoryRecipeDecisionTemplate(role: role, actionTemplate: action, gainTemplate: gain, costTemplate: cost)
    }

    static let catalogue: [String: VignetteParts] = [
        // Unquiet Folio
        "grey-edit": VignetteParts(
            place: "the warm back table of the Kitchens",
            premise: "Something grey has been at one of your kept pages. {{lead}} has it flat on the table: the words have gone pale, and someone has corrected them to \"fine.\"",
            happenings: [
                "Where the words were, the page now says \"fine\" in grey pencil, three times, very neatly.",
                "The grey pencil lies beside the page, warm, as if someone put it down a moment ago.",
                "One true letter is still there, holding on at the edge of the line like a person on a ledge.",
                "The lamp is turned up and the grey gets paler, but so does everything else on the table."
            ]
        ),
        "wicker-marks-the-page": VignetteParts(
            place: "a reading desk by the dormitory window",
            premise: "Wicker has written a note in the margin of one of your kept pages, in a hand that is almost yours, and has stayed to watch you find it.",
            happenings: [
                "The forged note is in green ink, and the ink is still wet enough to smudge.",
                "Wicker is reading a book upside down and humming, very innocently.",
                "The real words on the page have shuffled a little away from the forged note, like people moving seats.",
                "A second forged note appears while everyone is looking at the first one."
            ]
        ),
        "rivals-tether": VignetteParts(
            place: "a living map spread across the floor of the Map Room",
            premise: "A brass story-tether has fastened {{lead}} and {{companion}} to opposite ends of a living map. It shortens whenever either of them pretends a choice costs nothing.",
            happenings: [
                "The map draws a small rude face beside {{lead}}'s route.",
                "The tether yanks both of them a step closer with a sound like a dog's lead.",
                "A road on the map rolls itself up like a rug while they argue over it.",
                "A third road the map never marked appears in faint pencil, and the map pretends it has always been there."
            ]
        ),
        "counterfeit-invitation": VignetteParts(
            place: "the dormitory post shelf",
            premise: "An invitation has come for you, signed by a friend, and {{lead}} is holding it up to the lamp because the handwriting is wrong.",
            happenings: [
                "The signature is right but the ink smells of somebody else's pocket.",
                "The envelope reseals itself every time it's put down.",
                "The invitation gives a time that hasn't happened yet today, and a room nobody has heard of.",
                "Held up to the lamp, a second, fainter line of writing shows under the first."
            ]
        ),
        // Core
        "souvenir-door": VignetteParts(
            place: "the dormitory window seat",
            premise: "A sentence you kept has started to happen, very small, on the window seat.",
            happenings: [
                "The words of the sentence begin to happen in the room, one at a time, very small.",
                "A puddle no bigger than a saucer appears on the floorboards and holds a whole sky in it.",
                "The sentence's last word won't sit still and keeps trying to get out the window.",
                "Something in the sentence leaves a wet footprint on the page."
            ]
        ),
        "dorm-room-visit": VignetteParts(
            place: "your room in the dormitory",
            premise: "{{lead}} has knocked on your door with a reason, and has brought the wrong opening line.",
            happenings: [
                "{{lead}} has brought something wrapped in a napkin and keeps forgetting to hand it over.",
                "The kettle in your room boils by itself, the way it does when it wants company.",
                "{{lead}} starts the sentence three times and stops at the same word each time.",
                "Your door, which never closes properly, closes properly, and stays shut."
            ]
        ),
        "misdelivered-object": VignetteParts(
            place: "the post shelf in the dormitory hall",
            premise: "A parcel turns up on the post shelf with {{thing}} inside it, addressed to the wrong person, and it refuses to be delivered anywhere else.",
            happenings: [
                "Every label on the parcel names a different owner, and the handwriting gets crosser on each one.",
                "The parcel slides itself back onto the shelf every time someone picks it up.",
                "A second parcel arrives, smaller, with only a question mark on it.",
                "The string around it has been tied and untied so many times it has gone soft as wool."
            ],
            decisions: [
                decide(.sliceOfLife, "Keep the parcel safe on the shelf overnight", gain: "nobody loses anything tonight", cost: "the parcel sulks"),
                decide(.progressArc, "Carry it to the last name on the labels", gain: "someone finally gets what is theirs", cost: "it might not be the right someone"),
                decide(.surprise, "Open it and read the inside of the lid", gain: "the parcel's own idea of where it belongs", cost: "you can't un-open it")
            ]
        ),
        "tiny-heist": VignetteParts(
            place: "the corridor outside the staff room",
            premise: "{{lead}} has a plan for a very small, very harmless heist involving {{thing}}, and it depends on a door that squeaks on the third second.",
            happenings: [
                "The door squeaks on the second second instead.",
                "A portrait on the wall has been watching the whole time and clears its throat.",
                "The thing they came to take has already been taken, and there's a note.",
                "Someone inside the staff room starts humming the same tune {{lead}} is humming."
            ],
            decisions: [
                decide(.sliceOfLife, "Call it off and walk out whistling", gain: "nobody gets caught", cost: "the thing stays where it is"),
                decide(.progressArc, "Go now, on the squeak", gain: "the heist might actually work", cost: "it has to work first time"),
                decide(.surprise, "Knock and ask for it politely", gain: "the oddest possible success", cost: "the whole plan is wasted")
            ]
        ),
        "false-alarm": VignetteParts(
            place: "the dormitory landing",
            premise: "The landing's brass bell has started ringing for {{thing}}, which is not, by any sensible measure, an emergency.",
            happenings: [
                "The bell rings again, louder, the moment anyone stops looking at {{thing}}.",
                "A bucket of sand arrives on its own, ready for a fire that isn't there.",
                "The bell's rope is tied in a bow nobody remembers tying.",
                "Under the bell someone has chalked a list of everything it has rung for. The last line is blank."
            ],
            decisions: [
                decide(.sliceOfLife, "Sit with {{thing}} until the bell gives up", gain: "the bell learns what calm sounds like", cost: "nobody finds out what it was really warning about"),
                decide(.progressArc, "Follow where the bell's rope actually goes", gain: "the real warning turns up somewhere smaller", cost: "the landing has to stay noisy a while longer"),
                decide(.surprise, "Ring the bell back at it, once, firmly", gain: "the bell answers with a different note", cost: "the whole dormitory wakes up and wants to know why")
            ]
        ),
        "field-test": VignetteParts(
            place: "a workbench in the Book Burrow",
            premise: "{{lead}} has a theory about {{thing}} and one small safe test that could prove it wrong.",
            happenings: [
                "The test works on the first try, which makes {{lead}} deeply suspicious.",
                "The measuring tape refuses to lie flat and curls up like a cat.",
                "{{companion}} quietly changes one thing about the test while nobody is watching.",
                "The result comes out exactly the same as the guess, and the notebook writes \"hm\" in the margin by itself."
            ],
            decisions: [
                decide(.sliceOfLife, "Run the test once more, slowly", gain: "the result gets steadier", cost: "the theory stays small"),
                decide(.progressArc, "Take the test somewhere it might fail", gain: "the theory earns a real answer", cost: "{{lead}} might have to admit being wrong"),
                decide(.surprise, "Ask {{thing}} to run the test on you", gain: "the experiment turns around", cost: "nobody knows what it will measure")
            ]
        ),
        "nothing-library-corner": VignetteParts(
            place: "a corner of the library where the lamps are dim",
            premise: "In a library corner, something grey has started rubbing out {{thing}}, one small part at a time, and you're close enough to stop it.",
            happenings: [
                "The first thing to go is the colour. Then the edges.",
                "A rubber-crumb trail leads under the bookshelf, still warm.",
                "The shelf beside it has gone a little greyer too, and none of the books seem to mind.",
                "When someone says exactly what's there out loud, the rubbing stops for a moment and listens."
            ],
            decisions: [
                decide(.sliceOfLife, "Say out loud exactly what is there", gain: "the grey stops for tonight", cost: "it knows you're watching now"),
                decide(.progressArc, "Follow the rubber crumbs under the shelf", gain: "you find where the grey sleeps", cost: "the corner is left alone while you look"),
                decide(.surprise, "Give the grey something else to rub out", gain: "{{thing}} is safe", cost: "something else is gone instead")
            ]
        ),
        "small-discovery": VignetteParts(
            place: "a reading nook in the Book Burrow",
            premise: "{{lead}} has noticed that {{thing}} doesn't quite add up, and has spread it out on the nook table like evidence.",
            happenings: [
                "The obvious explanation fits perfectly, which is how {{lead}} knows it's wrong.",
                "A magnifying glass shows one detail that isn't there without it.",
                "{{companion}} finds a second one, exactly the same, in a place it can't possibly be.",
                "The table's own drawer opens a crack, like it knows something and would rather not say."
            ],
            decisions: [
                decide(.sliceOfLife, "Write down only what's certain", gain: "the clue stays honest", cost: "the mystery stays a mystery tonight"),
                decide(.progressArc, "Test the wrong explanation until it breaks", gain: "the real answer gets closer", cost: "something on the table might break with it"),
                decide(.surprise, "Open the drawer", gain: "the table tells what it knows", cost: "it may not be about this at all")
            ]
        ),
        "odd-favor": VignetteParts(
            place: "the bottom of the main stairs",
            premise: "{{lead}} needs a favour from you involving {{thing}}, and has left out the one awkward part.",
            happenings: [
                "The awkward part arrives on its own, in a basket, with a label.",
                "{{lead}} has drawn a diagram of the favour. It has an arrow labelled \"and then you\".",
                "The favour needs doing before the stairs change direction, which they do at the hour.",
                "Somebody else walks past, sees the basket, and walks faster."
            ],
            decisions: [
                decide(.sliceOfLife, "Do the favour exactly as asked", gain: "{{lead}} owes you one", cost: "you carry the awkward part"),
                decide(.progressArc, "Ask for the awkward part first", gain: "the favour gets honest", cost: "{{lead}} goes red"),
                decide(.surprise, "Hand the favour to someone better at it", gain: "it gets done properly", cost: "{{lead}} wanted it to be you")
            ]
        ),
        "shared-quiet": VignetteParts(
            place: "the warm end of the Kitchens",
            happenings: [
                "The pods split cleanly for a while, and then one won't open at all.",
                "The kettle starts to sing and stops halfway, as if it forgot the words.",
                "{{lead}} gets the remembered words slightly wrong and waits to be corrected.",
                "The bowl fills faster than two people could possibly be filling it."
            ]
        ),
        "trade-at-the-margin": VignetteParts(
            place: "the edge of the dormitory, where the margins meet",
            premise: "{{lead}} wants to make a trade: one small favour for {{thing}}, and the price is written in pencil so it can still change.",
            happenings: [
                "The price rubs itself out and writes itself back, a little higher.",
                "A third party arrives wanting the same thing and offering more.",
                "The favour turns out to be for someone who isn't here and won't say thank you.",
                "{{lead}} slides over a small brass key as a sweetener and won't say what it opens."
            ],
            decisions: [
                decide(.sliceOfLife, "Pay the first price and shake on it", gain: "the trade is clean and done", cost: "you never learn what it was worth"),
                decide(.progressArc, "Haggle the price down to something honest", gain: "both sides get a fair bargain", cost: "{{lead}} might take offence"),
                decide(.surprise, "Offer the key back as your payment", gain: "the trade turns upside down", cost: "you won't find out what it opens")
            ]
        ),
        "concrete-disagreement": VignetteParts(
            place: "the long table in the common room",
            premise: "{{lead}} and {{companion}} are looking at the same thing, {{thing}}, and have come to opposite conclusions about what to do with it.",
            happenings: [
                "Each of them has drawn a little map of what should happen next, and the maps cross in one place.",
                "The common room clock stops to listen.",
                "{{companion}} produces evidence from a pocket. It is a biscuit, and somehow it helps.",
                "They both turn out to be right about one thing, which makes it worse."
            ],
            decisions: [
                decide(.sliceOfLife, "Side with {{lead}} and say why", gain: "the argument ends tonight", cost: "{{companion}} won't forget it"),
                decide(.progressArc, "Ask each of them for the one fact that would change their mind", gain: "the real question comes out", cost: "it takes all evening"),
                decide(.surprise, "Decline to judge and cut the biscuit in half", gain: "they have to work it out together", cost: "nobody wins")
            ]
        ),
        "the-entrusting": VignetteParts(
            place: "the quiet end of the north corridor",
            premise: "{{lead}} has carried something private a long way and has decided you, nobody else, are the person to hold it.",
            happenings: [
                "{{lead}} checks the corridor twice, both ways, though it's empty.",
                "The thing is small enough to fit in a hand and heavier than it looks.",
                "{{lead}} starts to say it, stops, and says it plainly anyway.",
                "A lamp along the corridor goes out by itself, as if to give them some dark to say it in."
            ],
            decisions: [
                decide(.sliceOfLife, "Take it and say only thank you", gain: "{{lead}} doesn't have to explain", cost: "you hold it without knowing everything"),
                decide(.progressArc, "Ask the one careful question", gain: "you'll know how to keep it", cost: "{{lead}} has to say a little more"),
                decide(.surprise, "Give {{lead}} a small secret of your own in return", gain: "it becomes a trade between friends", cost: "now you're both holding something")
            ]
        ),
        "the-summons": VignetteParts(
            place: "the Kitchens door, where the summons arrives",
            premise: "{{lead}} has been sent with a summons: one small task in the Labyrinth can only be done by you, and the reason has something to do with {{thing}}.",
            happenings: [
                "The summons is written on a napkin, and the ink is still wet.",
                "A list of everyone who was asked before you is on the back. Every name is crossed out.",
                "The task is so small it's almost insulting, and {{lead}} is very serious about it.",
                "A bell somewhere in the building rings once, as if to say: now would be good."
            ],
            decisions: [
                decide(.sliceOfLife, "Go now, before the ink dries", gain: "the task gets done tonight", cost: "you go without knowing why"),
                decide(.progressArc, "Name your own hour for it", gain: "the summons waits for you", cost: "the Labyrinth has to trust you"),
                decide(.surprise, "Ask why it has to be you", gain: "you hear the real reason", cost: "the reason might be heavier than the task")
            ]
        ),
        "the-readers-mark": VignetteParts(
            place: "a stairwell landing in the Kitchens wing",
            premise: "Somewhere in the Kitchens wing, the building has quietly rebuilt one small corner around something you kept, and {{lead}} has found it.",
            happenings: [
                "A small new step has grown at the top of the stairs, just where someone would stop to listen.",
                "The landing's lamp now waits a beat before going out, as if listening.",
                "Somebody has already worn a path to the new thing, though it's only a day old.",
                "The mark is very easy to walk past. Two people do, while {{lead}} watches."
            ]
        ),
        "unshelved-expedition": VignetteParts(
            place: "the far rows of the Stacks, past where the map stops",
            happenings: [
                "The ladder has grown three rungs taller overnight and the top one is labelled DON'T.",
                "The map runs out halfway down the row, and the last thing drawn on it is a small door and a question mark.",
                "A shelf shuffles one book to the left, closing the gap they were about to squeeze through.",
                "A cold draft comes out of an empty space on the shelf, the shape of a book nobody has written yet."
            ],
            decisions: [
                decide(.sliceOfLife, "Take the bold route up the ladder", gain: "you reach the far shelf tonight", cost: "the ladder remembers who climbed it"),
                decide(.progressArc, "Take the clever route through the gap", gain: "the Stacks can't rearrange around you", cost: "it's very narrow and very dark"),
                decide(.surprise, "Take the kind route and ask the shelf", gain: "the Stacks might let you through", cost: "the shelf will want something back")
            ]
        ),
        "loose-in-the-quillquarium": VignetteParts(
            place: "the Quillquarium, a glass-walled room of tethered quills",
            happenings: [
                "The quill writes RUDE across the wall in perfect copperplate, then underlines it twice.",
                "It dives into an inkwell and comes out the other side with a different colour of ink.",
                "Every tethered quill in the room starts tapping its nib on the glass, cheering it on.",
                "It hides inside {{lead}}'s sleeve and signs a name on the inside of a wrist."
            ]
        ),
        "door-that-was-not-there": VignetteParts(
            place: "the third-floor corridor",
            happenings: [
                "A coat hangs on a hook beside the door. It is still warm, and its pockets are full of wet sand.",
                "The door knocks once from its own side. Politely. Then it waits.",
                "Every other door in the corridor swings shut at once, like people who would rather not be involved.",
                "A note slides out under the door in very neat handwriting. It says NOT YET."
            ]
        ),
        "great-hall-wager": VignetteParts(
            place: "the long tables of the Great Hall",
            happenings: [
                "The salt cellars slide down the tables to whichever side they think is winning.",
                "Someone has begun keeping score in butter on a bread plate, and the score is wrong.",
                "The portrait of the Founder clears its throat and asks to be told the stakes. Nobody answers it.",
                "Both rivals reach for the same final piece of evidence at the same moment, and it's a teaspoon."
            ]
        ),
        "weather-indoors": VignetteParts(
            place: "the long corridor on the second floor",
            happenings: [
                "It is raining in the corridor, and the rain is filing itself neatly into the umbrella stand.",
                "A small fog is reading the noticeboard over someone's shoulder.",
                "The corridor's sky thunders very quietly, the way people cough in a library.",
                "A puddle on the floor reflects a different ceiling, a much older one, with stars."
            ],
            decisions: [
                decide(.sliceOfLife, "Walk the whole corridor in the weather", gain: "you find out where the weather ends", cost: "you'll come out the other end soaked"),
                decide(.progressArc, "Bottle a sample of the indoor sky", gain: "the weather can be studied properly", cost: "it may not like the jar"),
                decide(.surprise, "Ask the weather which room it wants next", gain: "it might settle somewhere it's wanted", cost: "it might pick your room")
            ]
        ),
        "kitchens-at-midnight": VignetteParts(
            place: "the Kitchens, after hours",
            happenings: [
                "The onions refuse to be chopped until somebody tells them who the dish is for.",
                "A clean plate is already waiting at the pass with a name card turned face down.",
                "The big copper pot fills itself with water and starts, very gently, to boil out of turn.",
                "The pantry door is locked from the inside and something in there is humming."
            ],
            decisions: [
                decide(.sliceOfLife, "Make the humble dish and make it perfectly", gain: "one plate goes out honest and hot", cost: "nobody learns who the guest is"),
                decide(.progressArc, "Chase the ambitious dish against the clock", gain: "the Kitchens see what {{lead}} can really do", cost: "it might not be ready by midnight"),
                decide(.surprise, "Turn over the name card before cooking anything", gain: "the guest stops being a mystery", cost: "the guest knows someone looked")
            ]
        ),
        "forage-day": VignetteParts(
            place: "the damp lower rows of the Deep Stacks",
            happenings: [
                "A spine-snail is eating the title off a book, one gold letter at a time, and looks up as if caught.",
                "The basket gets heavier with nothing new in it, and then it hiccups.",
                "Something small and shiny is following the expedition, three shelves back, stopping whenever anyone turns around.",
                "The best patch of shelf-moss grows in the shape of a hand, palm up, like it's asking for something first."
            ],
            decisions: [
                decide(.sliceOfLife, "Pick the practical find and go home", gain: "the basket comes back useful", cost: "the shiny thing stays a mystery"),
                decide(.progressArc, "Follow the shiny thing deeper in", gain: "you find out what it is", cost: "the way back is less certain"),
                decide(.surprise, "Leave the best patch growing and mark the spot", gain: "the shelf trusts you next time", cost: "the basket comes home light")
            ]
        ),
        "night-apothecary": VignetteParts(
            place: "the infirmary shelf, open late",
            premise: "The infirmary shelf is open late. The patient tonight is a lamp that has lost its nerve, and the missing ingredient for its remedy is {{thing}}.",
            happenings: [
                "The ingredients line up on the shelf in order of who wants to go in the pot first.",
                "The lamp flickers every time someone says the word \"dose\".",
                "The mortar and pestle won't grind anything until it's been thanked.",
                "The remedy turns the wrong colour, then the right colour, then a colour nobody has a word for."
            ],
            decisions: [
                decide(.sliceOfLife, "Give the gentle dose and sit with the lamp", gain: "the lamp steadies a little tonight", cost: "it may need the shelf again tomorrow"),
                decide(.progressArc, "Give the strong dose all at once", gain: "the lamp could blaze back properly", cost: "it might be too much for it"),
                decide(.surprise, "Ask the lamp what it actually wants", gain: "the remedy changes completely", cost: "it might ask for something you don't have")
            ]
        ),
        "mending-basket": VignetteParts(
            place: "a low table in the Kitchens, with the mending basket on it",
            premise: "{{lead}} sets the mending basket on the table. Tonight's worn thing is {{thing}}, and something is wrong with it that a needle might fix.",
            happenings: [
                "The first stitch goes in and the thread changes colour to match something that isn't in the room.",
                "Under the wear there's a second, older mend, very bad, done by someone in a hurry.",
                "The needle won't go any further until somebody says out loud what happened to it.",
                "The thread runs out exactly halfway, and the spool is empty but warm."
            ],
            decisions: [
                decide(.sliceOfLife, "Make the mend invisible", gain: "it can be used tomorrow as if nothing happened", cost: "the old bad mend stays hidden under it"),
                decide(.progressArc, "Mend it in a bright thread that shows", gain: "the break becomes part of its story", cost: "everyone who sees it will ask"),
                decide(.surprise, "Teach it to hold itself together", gain: "it won't need the basket again", cost: "it might decide to come apart somewhere else")
            ]
        ),
        "naming-of-small-things": VignetteParts(
            place: "the bottom of the back stairs",
            happenings: [
                "The thing by the stairs has gone a little grey at the edges, like a photograph left in a window.",
                "Someone has stuck a note on it that just says \"that thing\", and the thing has turned its back on it.",
                "The stair above it creaks a name, a bad one, and the thing shudders.",
                "A row of rejected names is chalked on the wall beside it, all of them very flattering."
            ],
            decisions: [
                decide(.sliceOfLife, "Give it a plain, true name", gain: "the grey stops spreading tonight", cost: "the name might be too plain for it"),
                decide(.progressArc, "Ask what names it has overheard and liked", gain: "it gets to choose", cost: "it might choose something odd"),
                decide(.surprise, "Promise a name tomorrow and lend it a nickname", gain: "nobody rushes it", cost: "the grey gets one more night")
            ]
        ),
        "stall-night": VignetteParts(
            place: "a disused reading room where the Goblin Market has set up overnight",
            happenings: [
                "A stall is selling bottled hush, and one bottle has a crack and is leaking quiet.",
                "A goblin vendor offers to trade for the sound of your footsteps and seems serious.",
                "The best stall has no price on anything, just a sign: NAME YOUR OWN.",
                "Secondhand moonlight is piled in a basket, a bit creased, going cheap."
            ],
            decisions: [
                decide(.sliceOfLife, "Trade for something useful at the practical stall", gain: "you go home with a thing that works", cost: "it won't be the one you wanted"),
                decide(.progressArc, "Name your own price at the best stall", gain: "the finest thing in the Market", cost: "you have to pay what you named"),
                decide(.surprise, "Trade for a bottle of hush", gain: "a quiet you can open later", cost: "the goblin keeps a little of your voice")
            ]
        ),
        "small-observance": VignetteParts(
            place: "the window seat on the west landing",
            happenings: [
                "The candles are counted twice and come out a different number both times.",
                "The window has been unlatched for the ceremony's one guest, and something small is already sitting on the sill.",
                "The almanac turns its own page to the right day and taps it.",
                "Every instruction for the ceremony has been lost except one, in the margin: \"and then whoever is reading this holds it.\""
            ],
            decisions: [
                decide(.sliceOfLife, "Keep the tradition exactly as written", gain: "the observance is done properly", cost: "nobody learns why it's done"),
                decide(.progressArc, "Change it honestly to fit tonight", gain: "it fits the real season", cost: "the old way might sulk"),
                decide(.surprise, "Take the part nobody volunteered for", gain: "the ceremony gets its missing piece", cost: "you'll have to do it every year")
            ]
        ),
        "impossible-specimen": VignetteParts(
            place: "the registry desk in the Book Burrow",
            happenings: [
                "The lid lifts by itself a finger's width and a voice inside says, quite clearly, \"Ahem.\"",
                "Whatever is inside weighs more when nobody is looking at the scales.",
                "The last blank catalog card starts filling itself in, in handwriting that belongs to nobody in the room.",
                "The specimen's shadow is facing the wrong way and refuses to be corrected."
            ]
        ),
        "wrong-size-emergency": VignetteParts(
            place: "a narrow corridor by the linen cupboard",
            premise: "{{lead}} has arrived ready for a huge magical emergency (rope, a warning bell, an emergency cloak) because {{thing}} sounded much worse from the other side of the door. The real problem would fit in a teacup.",
            happenings: [
                "The warning bell goes off by itself, then looks embarrassed.",
                "The real problem is very small, very wet, and sitting in the teacup looking up.",
                "The emergency cloak keeps trying to be heroic and swirl, in a corridor too narrow for it.",
                "One piece of equipment nobody can explain turns out to be exactly the right size."
            ]
        ),
        "one-simple-conversation": VignetteParts(
            place: "an empty classroom being used for a rehearsal",
            premise: "{{lead}} only has to say one simple thing to {{companion}}. The rehearsal has somehow acquired cue cards, three opening lines, and a cape nobody authorized.",
            happenings: [
                "A fourth cue card has appeared. It just says BREATHE in capitals.",
                "The cape keeps adding a dramatic swish to sentences that don't need one.",
                "{{companion}} walks in early, while {{lead}} is still practising out loud.",
                "The one sentence, written on the board, is still short. Everything around it has got much longer."
            ]
        ),
        "rumor-with-good-shoes": VignetteParts(
            place: "the busy main corridor between lessons",
            premise: "A harmless misunderstanding about {{thing}} has put on excellent shoes and is walking briskly through the corridors. {{lead}} is one corridor behind and losing ground.",
            happenings: [
                "Everyone who passes has heard a newer, more specific, less accurate version.",
                "The rumor's footprints are very neat and getting faster.",
                "Somebody has already drawn a picture of the rumor on the noticeboard, and it has a hat now.",
                "The rumor is heading straight for the one person who will embroider it."
            ],
            decisions: [
                decide(.sliceOfLife, "Catch it with one short, true sentence", gain: "the rumor stops here", cost: "the true version is less fun"),
                decide(.progressArc, "Get to the person it's heading for first", gain: "they hear the real story", cost: "the rumor keeps going everywhere else"),
                decide(.surprise, "Declare it a legend and make it ridiculous", gain: "nobody could believe it now", cost: "it will be told for years")
            ]
        ),
        "petty-prophecy": VignetteParts(
            place: "the Great Hall, under the high windows",
            happenings: [
                "The gold letters of the prophecy are still smoking slightly where they hang in the air.",
                "The last clean spoon in the Hall has been placed on a velvet cushion, under guard.",
                "A crowd has gathered to watch a crooked button very closely.",
                "The prophecy adds a footnote in smaller letters, clearly hoping nobody reads it."
            ]
        ),
        "unscheduled-parade": VignetteParts(
            place: "the long west corridor",
            happenings: [
                "Someone at the back is playing an instrument that is mostly a drawer.",
                "The banner at the front says CONGRATULATIONS and nobody knows on what.",
                "One marcher is sure this is a funeral and is being very respectful.",
                "The parade turns a corner it hasn't been told about and keeps going."
            ]
        ),
        "rule-nobody-read": VignetteParts(
            place: "the library's long reading desk",
            happenings: [
                "The rulebook inks a late fee in the margin, then underlines it.",
                "The title of the rule runs off the end of the shelf and onto the next one.",
                "Clause eleven turns out to be about punctuation and is very upset about a comma.",
                "There is one footnote, very small, and the rulebook is sitting on it."
            ]
        ),
        "the-quill-disagrees": VignetteParts(
            place: "your writing desk",
            happenings: [
                "The quill writes one word in the margin, over and over, and it isn't the word on the page.",
                "A drop of ink falls exactly on the sentence the quill hates most.",
                "The quill turns itself round in the inkwell so its feather faces away from you.",
                "The quill's version of the page, in tiny letters at the bottom, is not entirely wrong."
            ]
        ),
        // Reader roles
        "role-maker-unfinished": VignetteParts(
            place: "the workshop bins behind the craft room",
            premise: "Somebody has given up on a half-made thing at exactly the stage where it's most alive, and is about to throw it out. {{lead}} has found them.",
            happenings: [
                "The half-made thing has one perfect part, and the rest is pencil marks.",
                "Its maker won't say what it was for, and won't let go of it either.",
                "The bin lid closes by itself, slowly, like it's being polite.",
                "Somebody has already written REJECTED on it and then crossed that out."
            ],
            decisions: [
                decide(.sliceOfLife, "Finish it roughly, tonight", gain: "it gets to be a whole thing", cost: "it won't be what its maker meant"),
                decide(.progressArc, "Keep it exactly as unfinished as it is", gain: "the alive part stays alive", cost: "it never gets used"),
                decide(.surprise, "Give it to someone who'll finish it wrong", gain: "it becomes something new", cost: "its maker has to watch")
            ]
        ),
        "role-lookout-weather-turned": VignetteParts(
            place: "the window at the end of the long corridor",
            premise: "The weather over the Academy has just done something very particular, and nobody inside has looked up yet except {{lead}}.",
            happenings: [
                "The sky does it again, slower, as if for the people at the back.",
                "Everyone in the corridor walks past the window with a good reason not to look.",
                "A bird lands on the sill and also looks up.",
                "The window steams over at the corners, framing the sky like a picture."
            ],
            decisions: [
                decide(.sliceOfLife, "Go out and look alone", gain: "you see all of it", cost: "nobody will believe you"),
                decide(.progressArc, "Drag one person to the window", gain: "someone else sees it too", cost: "it might stop just as they look"),
                decide(.surprise, "Stay in and write down exactly what it did", gain: "it's kept, properly", cost: "you miss the end")
            ]
        ),
        "role-porchlight-light-left-on": VignetteParts(
            place: "the common room, late",
            premise: "Two people have stopped speaking to each other, and both are waiting for the other to make it easy. {{lead}} is in the room with both of them.",
            happenings: [
                "They both reach for the same book and both let go.",
                "One of them says something to the fire that is clearly meant for the other.",
                "The lamp they're sitting under is the only one still on, and neither will turn it off.",
                "A cup of tea goes cold between them, poured for nobody."
            ],
            decisions: [
                decide(.sliceOfLife, "Hold the room open and say nothing", gain: "they can go first in their own time", cost: "it might take all night"),
                decide(.progressArc, "Make the first move for them", gain: "the silence breaks tonight", cost: "it's your move, not theirs"),
                decide(.surprise, "Say the unsaid thing plainly", gain: "it's out in the open", cost: "you said it, so it's yours now")
            ]
        ),
        "role-detourist-wrong-way": VignetteParts(
            place: "a side passage off the usual route",
            premise: "The usual route is closed tonight, and the way round goes somewhere the usual way never passed. {{lead}} is already halfway down it.",
            happenings: [
                "The detour passes a window that looks out onto a room inside the building.",
                "A sign on the wall says THIS WAY in old paint, pointing back the way they came.",
                "There's a bench here, worn smooth, as if lots of people have taken this wrong turn.",
                "Everybody else is taking the right way, which is right there, and it is very sensible."
            ],
            decisions: [
                decide(.sliceOfLife, "Sit on the worn bench a while", gain: "you see what this place is for", cost: "you'll be late for everything"),
                decide(.progressArc, "Follow the detour to its end", gain: "you find where it really goes", cost: "the way back might not be here"),
                decide(.surprise, "Go back and tell someone about it", gain: "the wrong way gets a second visitor", cost: "it might not be secret any more")
            ]
        ),
        "role-rabbit-holer-one-more": VignetteParts(
            place: "the library, long after it should have closed",
            premise: "A small question about {{thing}} has turned out to have a much longer answer than anyone expected, and {{lead}} is following it past the point where that was reasonable.",
            happenings: [
                "There are eleven books open on the table, and each one points to a twelfth.",
                "The library clock has been politely coughing for an hour.",
                "{{lead}} finds a note in the margin from someone who followed the same question years ago and stopped here.",
                "The answer is in the next book, and the next book is on the very top shelf."
            ],
            decisions: [
                decide(.sliceOfLife, "Stop here and write down where you got to", gain: "nothing is lost", cost: "the answer waits another day"),
                decide(.progressArc, "Go one book deeper", gain: "you might reach the bottom", cost: "there might not be one"),
                decide(.surprise, "Leave a note for the next person, like the last one did", gain: "the question has company", cost: "you won't see where it ends")
            ]
        ),
        "role-nightlight-small-hours": VignetteParts(
            place: "the kitchen, very late, with only the small light on",
            premise: "It's very late, and somebody who should be asleep isn't, and doesn't want the big lights on. {{lead}} has found them.",
            happenings: [
                "The kettle has been filled and not switched on.",
                "The small light over the stove hums, the only thing awake on purpose.",
                "They say something that could only be said at this hour, and then pretend they didn't.",
                "The clock on the wall is ticking quieter than usual, as if it's trying not to interrupt."
            ],
            decisions: [
                decide(.sliceOfLife, "Stay without saying anything", gain: "they aren't alone", cost: "nothing gets said"),
                decide(.progressArc, "Say the one true thing", gain: "it's said while it can be", cost: "the morning has to live with it"),
                decide(.surprise, "Switch on the kettle and send them to bed kindly", gain: "the night ends gently", cost: "whatever it was waits")
            ]
        ),
        "role-steady-hand-holds": VignetteParts(
            place: "a back corridor behind the Great Hall",
            premise: "Something is coming apart on a schedule, and everybody is in a meeting about it except the person quietly holding it together. {{lead}} is that person.",
            happenings: [
                "The meeting can be heard through the wall. Nobody in it has said {{lead}}'s name.",
                "The thing {{lead}} is holding slips, and {{lead}} catches it without looking.",
                "A list of the things {{lead}} does every day is pinned up, and it's very long, and nobody has read it.",
                "The clock says the schedule has eleven minutes left."
            ],
            decisions: [
                decide(.sliceOfLife, "Say the work out loud, so it's seen", gain: "{{lead}} is noticed", cost: "{{lead}} hates being noticed"),
                decide(.progressArc, "Learn to do it, so {{lead}} isn't alone", gain: "it has two keepers now", cost: "you've got a new job"),
                decide(.surprise, "Let it fail once, on purpose", gain: "everyone finally sees what it took", cost: "something actually breaks")
            ]
        ),
        "role-stowaway-not-invited": VignetteParts(
            place: "the back of a crowded room where something is happening",
            premise: "Something is happening that {{lead}} has no standing to be at, and the door wasn't locked.",
            happenings: [
                "There are name cards on every chair, and none of them say {{lead}}.",
                "Someone hands {{lead}} a programme without looking up.",
                "The thing being shown is better from in here than anyone could have described it.",
                "A steward starts counting heads from the front of the room."
            ],
            decisions: [
                decide(.sliceOfLife, "Stay and be counted", gain: "{{lead}} sees all of it", cost: "someone will ask who invited you"),
                decide(.progressArc, "Slip out with what you came for", gain: "nobody ever knows", cost: "you can't tell anyone either"),
                decide(.surprise, "Ask plainly to be let in", gain: "you might be welcomed", cost: "you might be sent away")
            ]
        )
    ]
}

extension VignetteBrief {
    /// After the choice, the reader has done exactly one thing.
    static let consequenceSystem = """
    You are a storybook telling the rest of a scene to the person reading you, so the reader is "you".
    Present tense. Tell it the way a good storyteller reads aloud: specific things, odd or funny details, and plenty of talk. People say what they think in their own way. Use "says". Don't describe how voices sound, and keep adjectives few.
    You did one thing: what you chose. You do nothing else, and you never speak, think or feel. Other people act, and they talk to you.
    Only the people named in the brief are in the scene.
    """

    /// The consequence as a beat sheet too: the choice happens, it wins what it
    /// wins, it costs what it costs, someone answers, and the changed fact
    /// lands. Every part is authored or precommitted; Gemma tells it.
    static func consequence(
        for plan: VignettePlan,
        scene: String,
        choice: String,
        gain: String?,
        cost: String?,
        reactor: String?,
        landing: String
    ) -> String {
        let people = [plan.lead.name, plan.companion?.name].compactMap { $0 }.joined(separator: " and ")
        let who = reactor.map { VignettePlanBuilder.pageName(fullName: $0) } ?? plan.lead.name
        let told = VignettePlanBuilder.secondPerson
        var beats = ["You choose: \(choice)."]
        if let gain { beats.append("It works: \(told(gain)).") }
        if let cost {
            beats.append("But \(told(cost)). \(who) says, \"\(VignetteShapes.speechSlot)\"")
        } else {
            beats.append("\(who) says, \"\(VignetteShapes.speechSlot)\"")
        }
        beats.append("\(told(landing)) The scene ends there.")
        let numbered = beats.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        Place: \(plan.place).
        People: \(people), and you.

        The scene so far:
        \(scene)

        What happens next, in order:
        \(numbered)

        Tell the rest of the scene in 3 paragraphs of 50 to 80 words each. Don't retell the scene so far. Replace every <...> with the real words.
        """
    }
}

/// What a telling must carry for the plan to have happened, and the one
/// cleanup that is always safe. Craft is not a veto here: these are the
/// failures a reader would see as broken, not as plain.
enum VignetteTellingCheck {
    static let minimumWords = 150

    static func failures(in scene: String, plan: VignettePlan) -> [String] {
        var failures: [String] = []
        if hasUnfilledSlot(scene) {
            failures.append("Every <...> must become the real words someone says.")
        }
        let lower = scene.lowercased()
        for speaker in [plan.lead, plan.companion].compactMap({ $0 }) {
            let surname = speaker.name.split(separator: " ").last.map { String($0).lowercased() } ?? speaker.name.lowercased()
            if !lower.contains(surname) {
                failures.append("\(speaker.name) is in this scene and has to be on the page.")
            }
        }
        if scene.split(whereSeparator: \.isWhitespace).count < minimumWords {
            failures.append("Tell the whole scene: four paragraphs.")
        }
        for happening in plan.happenings where !landed(happening, in: scene) {
            failures.append("Show this happening in the scene: \(happening)")
        }
        return failures
    }

    /// An authored happening has landed when enough of its own words made it
    /// into the telling. The model retells rather than quotes, so this asks
    /// for most of the content words, not the sentence.
    static func landed(_ happening: String, in scene: String) -> Bool {
        let wanted = contentWords(happening)
        guard !wanted.isEmpty else { return true }
        let present = contentWords(scene)
        let hits = wanted.filter { present.contains($0) }.count
        return Double(hits) >= max(2, Double(wanted.count) * 0.4)
    }

    /// Drops any sentence still holding a speech slot. A plain gap reads
    /// better than "<their words>" on a leaf.
    /// Also drops a sentence where you do something you never chose ("You sit
    /// still, observing", "You nod"): the reader acts only at the decision.
    static func cleaned(_ scene: String) -> String {
        var paragraphs = scene.components(separatedBy: "\n\n")
        if hasUnfilledSlot(scene) || inventsReaderAct(scene) {
            paragraphs = paragraphs.map { paragraph in
                sentences(in: paragraph).filter { !hasUnfilledSlot($0) && !inventsReaderAct($0) }.joined(separator: " ")
            }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        // The scene stops at its question. "The question hangs in the air,
        // demanding an answer" after it is the model clearing its throat.
        if var last = paragraphs.last {
            let parts = sentences(in: last)
            if let ask = parts.lastIndex(where: { $0.contains("?") }), ask < parts.count - 1 {
                last = parts[...ask].joined(separator: " ")
                paragraphs[paragraphs.count - 1] = last
            }
        }
        return paragraphs.joined(separator: "\n\n")
    }

    static func inventsReaderAct(_ text: String) -> Bool {
        text.range(
            of: #"(?m)(^|[.!?]\s+)You (observe|observed|watch|watched|nod|nodded|smile|smiled|pause|paused|feel|felt|sit still|lean|leaned|reach|reached|brace|step|stepped|say|said|decide|decided|look at|wonder)\b"#,
            options: .regularExpression
        ) != nil
    }

    static func hasUnfilledSlot(_ text: String) -> Bool {
        if text.range(of: #"<[^<>\n]{1,60}>"#, options: .regularExpression) != nil { return true }
        return text.range(of: #"[“"]\s*(…|\.\.\.)\s*\??\s*[”"]"#, options: .regularExpression) != nil
    }

    private static func sentences(in paragraph: String) -> [String] {
        var out: [String] = []
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespaces), !sentence.isEmpty { out.append(sentence) }
        }
        return out.isEmpty ? [paragraph] : out
    }

    private static let stopWords: Set<String> = [
        "the", "and", "with", "from", "that", "this", "into", "then", "they", "them", "their", "there",
        "were", "when", "what", "which", "while", "would", "could", "about", "after", "before", "every",
        "itself", "nobody", "somebody", "someone", "anyone", "very", "like", "once", "only", "than", "been"
    ]

    private static func contentWords(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 && !stopWords.contains($0) })
    }
}
