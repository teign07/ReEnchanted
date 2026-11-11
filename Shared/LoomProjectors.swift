import Foundation

/// What a projector is allowed to look at.
///
/// Deliberately a struct with defaults rather than a long argument list: a
/// projector that later needs the Fae ledger or the Workings adds a field here
/// and every existing projector keeps compiling.
struct GrimoireSlice {
    var days: [BookDay]
    /// Raw day rows make quiet days and reader-reported state countable. They
    /// are not inferred or filled forward.
    var daybookRows: [DaybookEntry] = []
    /// Explicit answers, including delayed verdicts tied to an earlier Page.
    var readerStatePulses: [ReaderStatePulseRecord] = []
    /// Thread id to display name, for the people projector.
    var peopleNames: [String: String] = [:]
    /// Dated Fae receipts. Only bargains carry dates, which is why the Fae
    /// projector counts encounters rather than warmth: warmth is a running
    /// total with no day attached, and a correspondence needs a day.
    var faeBargains: [FaeBargain] = []
    /// Finished Workings, which carry both when they were set and whether the
    /// reader ever came back to them.
    var workings: [BookWorking] = []
    /// Talisman errands: asked on one day, paid or lapsed on another. The
    /// paying is a real-world act, which is what makes it worth counting.
    var pactErrands: [PactErrand] = []
    /// When the Book spoke unprompted, and whether the reader answered.
    var asideReceipts: [BookAsideReceipt] = []
    /// Real objects the reader pressed into the Book's Pocket.
    var pocketKeepsakes: [PocketKeepsake] = []
    /// Book Jumps the reader came back from, and what they brought.
    var returnedJumps: [ReturnedBookJump] = []
    /// Observances the Book keeps for the reader, and whether they were kept.
    var traditions: [BookPrivateTradition] = []
    /// World events running on a given day, with the phase they were in.
    var worldEvents: [ResolvedWorldEvent] = []
    /// Where-were-you Knocks the reader answered, each carrying its own moment.
    var knocks: [AttentionProbeReceipt] = []
    /// Radio stations by the days the reader listened. Names are resolved where
    /// the station catalogue lives, so the projector stays a pure read.
    var radioDays: [RadioListeningDays] = []
    /// The rooms of the Book the reader went into by hand, by day.
    var wear: ReaderWearLedger = ReaderWearLedger()
    /// Inkbones throws, the reader's and the Curse's.
    var inkbones: [InkbonesThrowRecord] = []
    /// Pages the Curse put in the grey, and how each one ended.
    var greyPages: [GreyPageThreat] = []
    /// Electives the Cast set, finished or not.
    var electives: [UnwrittenElective] = []
    /// The places the reader has named on the map.
    var namedPlaces: [AnchorRecord] = []
    /// Semantic threads already worked out elsewhere. Used only to mark which
    /// of the reader's own Pages carried a subject; nothing here is re-derived.
    var continuity: LiteraryContinuityDigest = .empty
    var calendar: Calendar = .current
}

/// One source of trustworthy facts about a day.
///
/// This is the whole extension point. Adding music, or tides, or how long a
/// Page stayed open means writing one of these and adding a line to
/// `GrimoireProjection.registered`. Nothing in the ledger, the sweep or the
/// scoring knows what kinds of thing exist, so none of it has to change.
enum LoomProjectorDayScope {
    /// The fact describes the day and may safely accompany each Page in it.
    case wholeDay
    /// The fact happened at its own time and must remain a separate event.
    case event
}

protocol LoomProjector {
    static var id: String { get }
    /// The families this projector can produce, for documentation and lint.
    static var domains: [String] { get }
    static var dayScope: LoomProjectorDayScope { get }
    /// Read one kept Page.
    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef]
    /// Read a whole day, whether or not anything was kept. This is how absence
    /// becomes countable: a day the reader wrote nothing is still a row.
    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef]
    /// Did this day's receipt exist because the Book asked for it?
    ///
    /// The reader still did the thing — but they did it because they were
    /// asked, so it cannot also serve as free proof that the asking was right.
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool
    /// Read one raw Daybook row. Most sources do not have one.
    static func features(forDaybook entry: DaybookEntry, in slice: GrimoireSlice) -> [LoomFeatureRef]
    /// Read one explicit reader-state answer. Most sources do not have one.
    static func features(forPulse pulse: ReaderStatePulseRecord, in slice: GrimoireSlice) -> [LoomFeatureRef]
    /// Read one answered Knock. Only the Knock projector has one.
    static func features(forKnock receipt: AttentionProbeReceipt, in slice: GrimoireSlice) -> [LoomFeatureRef]
}

extension LoomProjector {
    static var dayScope: LoomProjectorDayScope { .wholeDay }
    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool { false }
    static func features(forDaybook entry: DaybookEntry, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func features(forPulse pulse: ReaderStatePulseRecord, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func features(forKnock receipt: AttentionProbeReceipt, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
}

// MARK: - Running them

enum GrimoireProjection {

    /// The registry. One line per source.
    static let registered: [any LoomProjector.Type] = [
        WorldConditionsProjector.self,
        DayShapeProjector.self,
        KeptPageProjector.self,
        ReaderWordsProjector.self,
        StoryTagProjector.self,
        PeopleProjector.self,
        InnerWeatherProjector.self,
        FaeEncounterProjector.self,
        WorkingProjector.self,
        CompassRunProjector.self,
        DaybookProjector.self,
        ReaderStateProjector.self,
        SensoryProjector.self,
        MeaningProjector.self,
        MoonProjector.self,
        PactErrandProjector.self,
        AsideReplyProjector.self,
        PocketProjector.self,
        BookJumpProjector.self,
        ObservanceProjector.self,
        AlmanacProjector.self,
        WorldEventProjector.self,
        KnockProjector.self,
        RadioProjector.self,
        WanderProjector.self,
        InkbonesProjector.self,
        GreyPageProjector.self,
        ElectiveProjector.self,
        PlaceMakingProjector.self
    ]

    /// Circumstances that arrived together, as one condition.
    ///
    /// "Parking lots after rain" is not a place and a weather; it is a third
    /// thing, and only a compound condition can say it. Two-way only, and
    /// capped: every extra feature on an observation multiplies the pairs the
    /// ledger has to remember, and three-way blends are where that stops paying.
    ///
    /// One half must be substantial — a place, a weather, a body signal. Blends
    /// of two ambient facts ("a weekday in spring") are shapeless.
    /// Three, not six. Blends were 80% of the feature table at six, and every
    /// extra feature on an observation multiplies the pairs the ledger keeps.
    static let blendCap = 3
    /// Declared here because blends are made in the projection step rather than
    /// by any one projector, and coverage checks should still see them.
    static let blendDomain = "contextBlend"

    private static let substantialDomains: Set<String> = ["weather", "place", "body", "sleep"]
    /// Only the hour. A weekday in spring is two ambient facts and describes
    /// nothing; both are already available as plain conditions on their own.
    /// `placeKind` is left out too — blended with `place` it is near-tautology.
    private static let ambientDomains: Set<String> = ["hour"]

    static func blends(from features: [LoomFeatureRef]) -> [LoomFeatureRef] {
        let candidates = features
            .filter { substantialDomains.contains($0.domain) || ambientDomains.contains($0.domain) }
            .filter { $0.role != .outcomeOnly && $0.sensitivity == .ordinary }
            .sorted { $0.id < $1.id }
        guard candidates.count > 1 else { return [] }
        var out: [LoomFeatureRef] = []
        for leftIndex in candidates.indices {
            for rightIndex in candidates.indices where rightIndex > leftIndex {
                guard out.count < blendCap else { return out }
                let left = candidates[leftIndex]
                let right = candidates[rightIndex]
                guard left.domain != right.domain else { continue }
                guard substantialDomains.contains(left.domain)
                        || substantialDomains.contains(right.domain) else { continue }
                out.append(LoomFeatureRef(
                    id: "blend:\(left.id)+\(right.id)", domain: "contextBlend",
                    // A label is read aloud in headlines. "evening + clear"
                    // is a spreadsheet cell; "evening and clear" is a day.
                    label: "\(left.label) and \(right.label)",
                    conditionClause: "\(left.conditionClause) and \(right.conditionClause)",
                    outcomeClause: "those two came together",
                    symbolName: "point.3.connected.trianglepath.dotted",
                    // A blend is a circumstance the reader was inside, never a
                    // thing they produced.
                    role: .conditionOnly,
                    provenance: .observedContext, rank: 2
                ))
            }
        }
        return out
    }

    /// Turn a slice of archive into observations the ledger can fold in.
    ///
    /// Several event-aligned observations may land on one day. The bitsets
    /// still count that as one day, while candidate generation only joins facts
    /// that belonged to the same Page, raw day row, or dated system event. That
    /// distinction prevents a rainy night Page from lending its weather to an
    /// unrelated Fae encounter that happened that morning.
    static func observations(
        from slice: GrimoireSlice,
        projectors: [any LoomProjector.Type] = registered
    ) -> [LoomObservation] {
        var out: [LoomObservation] = []
        out.reserveCapacity(slice.days.count * 2 + slice.daybookRows.count + slice.readerStatePulses.count)

        func unique(_ groups: [[LoomFeatureRef]]) -> [LoomFeatureRef] {
            var seen = Set<String>()
            return groups.flatMap { $0 }.filter { seen.insert($0.id).inserted }
        }

        for day in slice.days {
            let dayIndex = GrimoireDay.index(for: day.date, calendar: slice.calendar)
            let wholeDay = unique(projectors
                .filter { $0.dayScope == .wholeDay }
                .map { $0.features(forDay: day, in: slice) })
            let baseline = DayShapeProjector.features(forDay: day, in: slice)
            out.append(LoomObservation(
                id: "day:\(day.id)", day: dayIndex, occurredAt: day.date,
                features: unique([baseline, wholeDay]), evidencePageID: nil, evidenceLine: ""
            ))

            // Each dated system is its own event. Two unrelated ledgers merely
            // sharing a date do not get to corroborate each other.
            for projector in projectors where projector.dayScope == .event {
                let event = projector.features(forDay: day, in: slice)
                guard !event.isEmpty else { continue }
                out.append(LoomObservation(
                    id: "day-event:\(projector.id):\(day.id)", day: dayIndex, occurredAt: day.date,
                    features: unique([baseline, event]), evidencePageID: nil, evidenceLine: "",
                    bookAsked: projector.bookAsked(forDay: day, in: slice)
                ))
            }

            for page in day.capturedPages {
                let pageFeatures = projectors.flatMap { $0.features(forPage: page, in: slice) }
                var features = unique([wholeDay, pageFeatures])
                features += blends(from: features)
                guard features.count >= 2 else { continue }
                out.append(LoomObservation(
                    id: "page:\(page.id)", day: dayIndex, occurredAt: page.createdAt,
                    features: features, evidencePageID: page.id,
                    evidenceLine: page.reflectiveMaterial ?? ""
                ))
            }
        }

        for entry in slice.daybookRows.sorted(by: { $0.date < $1.date }) {
            let dayIndex = GrimoireDay.index(for: entry.date, calendar: slice.calendar)
            let baseline = DayShapeProjector.features(forDaybook: entry, in: slice)
            let observed = projectors.flatMap { $0.features(forDaybook: entry, in: slice) }
            let features = unique([baseline, observed])
            guard features.count >= 2 else { continue }
            out.append(LoomObservation(
                id: "daybook:\(entry.id)", day: dayIndex, occurredAt: entry.date,
                features: features, evidencePageID: nil, evidenceLine: ""
            ))
        }

        for pulse in slice.readerStatePulses.sorted(by: { $0.answeredAt < $1.answeredAt }) {
            let dayIndex = GrimoireDay.index(for: pulse.answeredAt, calendar: slice.calendar)
            let temporal = DayShapeProjector.temporalFeatures(at: pulse.answeredAt, in: slice)
            let state = projectors.flatMap { $0.features(forPulse: pulse, in: slice) }
            let context = pulse.context.map { WorldConditionsProjector.features(for: $0) } ?? []
            let features = unique([temporal, context, state])
            guard features.count >= 2 else { continue }
            out.append(LoomObservation(
                id: "pulse:\(pulse.id)", day: dayIndex, occurredAt: pulse.answeredAt,
                features: features, evidencePageID: pulse.target?.pageID,
                evidenceLine: pulse.answerLine
            ))
        }

        // A Knock is its own moment, like a pulse: the weather, place and hour
        // it caught the reader in travel with the answer and nowhere else.
        for receipt in slice.knocks.sorted(by: { $0.answeredAt < $1.answeredAt }) {
            let answer = projectors.flatMap { $0.features(forKnock: receipt, in: slice) }
            guard !answer.isEmpty else { continue }
            let dayIndex = GrimoireDay.index(for: receipt.answeredAt, calendar: slice.calendar)
            let temporal = DayShapeProjector.temporalFeatures(at: receipt.answeredAt, in: slice)
            let context = receipt.context.map { WorldConditionsProjector.features(for: $0) } ?? []
            out.append(LoomObservation(
                id: "knock:\(receipt.id)", day: dayIndex, occurredAt: receipt.answeredAt,
                features: unique([temporal, context, answer]), evidencePageID: nil,
                evidenceLine: receipt.sentence ?? ""
            ))
        }
        return out
    }
}

// MARK: - Small shared shapes

private func humanised(_ token: String) -> String {
    token.replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .trimmingCharacters(in: .whitespaces)
}

/// A word with its "a" or "an". The projectors only hand it ordinary nouns, so
/// the first letter is enough.
private func withArticle(_ noun: String) -> String {
    guard let first = noun.lowercased().first else { return noun }
    return ("aeiou".contains(first) ? "an " : "a ") + noun
}

/// A token as words. Apple's place categories arrive camel-cased
/// ("nationalPark") and `humanised` only knows about hyphens, which is how
/// "you went to a nationalPark" was possible.
private func spacedWords(_ token: String) -> String {
    var out = ""
    for character in token {
        if character == "-" || character == "_" {
            out.append(" ")
        } else if character.isUppercase, let last = out.last, !last.isWhitespace {
            out.append(" ")
            out.append(contentsOf: character.lowercased())
        } else {
            out.append(character)
        }
    }
    return out.split(separator: " ").joined(separator: " ")
}

/// Weather tags arrive as bare nouns and bare adjectives in the same list —
/// "rain" beside "clear" — and both were being dropped into "it was ___".
/// "It was clear" is a sentence. "It was rain" is not, and the reader meets
/// these clauses in the middle of a claim the Book is asking them to check.
///
/// The label is what the Book calls days like that, so it has to work as the
/// thing a sentence is about: "Rainy days kept turning up."
private func weatherClauses(_ tag: String) -> (label: String, condition: String, outcome: String) {
    let word = humanised(tag).lowercased()
    let known: [String: (String, String, String)] = [
        "rain": ("rainy days", "it was raining", "the rain came"),
        "drizzle": ("drizzly days", "it was drizzling", "the drizzle came"),
        "shower": ("showery days", "it was showering", "the showers came"),
        "showers": ("showery days", "it was showering", "the showers came"),
        "snow": ("snowy days", "it was snowing", "the snow came"),
        "sleet": ("sleety days", "it was sleeting", "the sleet came"),
        "hail": ("hail days", "it was hailing", "the hail came"),
        "fog": ("foggy days", "it was foggy", "the fog came"),
        "mist": ("misty days", "it was misty", "the mist came"),
        "haze": ("hazy days", "it was hazy", "the haze came"),
        "wind": ("windy days", "it was windy", "the wind came"),
        "storm": ("stormy days", "there was a storm", "a storm came"),
        "thunderstorm": ("thunderstorm days", "there was a thunderstorm", "a thunderstorm came"),
        "thunder": ("thundery days", "there was thunder", "the thunder came"),
        "cloud": ("cloudy days", "it was cloudy", "the clouds came"),
        "clouds": ("cloudy days", "it was cloudy", "the clouds came"),
        "sun": ("sunny days", "it was sunny", "the sun came out"),
        "sunshine": ("sunny days", "it was sunny", "the sun came out"),
        "ice": ("icy days", "it was icy", "the ice came"),
        "frost": ("frosty days", "it was frosty", "the frost came")
    ]
    if let found = known[word] { return found }
    // Anything that already reads as a description of the day is left alone:
    // clear, overcast, cold, warm, humid, breezy, freezing, grey.
    let looksLikeADescription = word.hasSuffix("y") || word.hasSuffix("ing")
        || word.hasSuffix("ed") || word.hasSuffix("cast") || word.hasSuffix("m")
        || ["clear", "cold", "hot", "damp", "dry", "grey", "gray", "fair", "mild",
            "crisp", "bright", "dark", "wet", "cool"].contains(word)
    if looksLikeADescription { return ("\(word) days", "it was \(word)", "the sky was \(word)") }
    // An unrecognised noun. "There was fogbow" is odd but it is a sentence,
    // which is more than the old line managed.
    return ("days with \(word)", "there was \(word)", "\(word) came")
}

/// A name that starts a sentence in its own right ("The Ember Seal"), tucked
/// into the middle of one: "the Ember Seal asked you for something".
private func midSentence(_ name: String) -> String {
    for article in ["The ", "A ", "An "] where name.hasPrefix(article) {
        return article.lowercased() + name.dropFirst(article.count)
    }
    return name
}

/// An Anchor's id is a slug ("user-anchor-the-kitchen-1a2b3c4d"), and no slug
/// reaches prose. The reader's own name for it is inside, so it comes back out;
/// anything that is already words is left alone.
private func anchorName(_ id: String) -> String {
    if id.contains(" ") { return id }
    guard id.hasPrefix("user-anchor-") else { return "one of your Anchors" }
    var parts = id.dropFirst("user-anchor-".count).split(separator: "-").map(String.init)
    if let last = parts.last, last.count == 8, last.allSatisfy(\.isHexDigit) { parts.removeLast() }
    return parts.isEmpty ? "one of your Anchors" : parts.joined(separator: " ")
}

/// Apple's place categories in the words a child would use for them.
/// Anything not listed is just spaced out: "nationalPark" is "national park".
private func placeKindWords(_ kind: String) -> String {
    let plain: [String: String] = [
        "atm": "cash machine", "evCharger": "car charger", "fitnessCenter": "gym",
        "foodMarket": "food shop", "gasStation": "petrol station", "movieTheater": "cinema",
        "publicTransport": "train or bus stop", "restroom": "toilet", "store": "shop",
        "nightlife": "place to go out at night", "carRental": "car hire place"
    ]
    return plain[kind] ?? spacedWords(kind).lowercased()
}

/// Bundled story genres and forms by id. Read once: the registry's own
/// accessors go to disk for the reader's packs, and these are asked per Page.
private let storyGenreNames: [String: String] = Dictionary(
    StoryFormRegistry.bundledPacks.flatMap(\.genres).map { ($0.id.lowercased(), $0.name) },
    uniquingKeysWith: { first, _ in first }
)
private let storyFormNames: [String: String] = Dictionary(
    StoryFormRegistry.bundledPacks.flatMap(\.forms).map { ($0.id.lowercased(), $0.name) },
    uniquingKeysWith: { first, _ in first }
)

/// "cozy mystery", ready to sit after "a". A genre whose name already ends in
/// "story" loses it, so nothing reads "a kindly ghost story story".
private func genreName(_ token: String) -> String {
    var name = (storyGenreNames[token] ?? spacedWords(token)).lowercased()
    if name.hasSuffix(" story") { name.removeLast(" story".count) }
    return name
}

/// "the Small Mystery", ready to sit after "shaped like".
private func formName(_ token: String) -> String {
    if let name = storyFormNames[token] { return midSentence(name) }
    return withArticle(spacedWords(token))
}

/// What a Working is called mid-sentence, one at a time and as a habit.
/// The recipe id is a filing label ("book-stolen-opening") and was reaching
/// the page as "a book stolen opening was set".
private func errand(_ working: BookWorking) -> (one: String, many: String) {
    switch working.recipeID {
    case "book-stolen-opening": return ("an opening I stole in your day", "the openings I steal in your day")
    case "wicker-case-against-routine": return ("one of Wicker's objections", "Wicker's objections")
    case "serenity-small-detour": return ("one of Serenity's detours", "Serenity's detours")
    case "trencher-table-kept-open": return ("one of Trencher's open tables", "Trencher's open tables")
    default:
        // A recipe nobody has named here yet. Its id is the only thing that
        // tells two of them apart, so it is said as words.
        let name = spacedWords(working.recipeID).lowercased()
        return (withArticle(name), "\(name)s")
    }
}

/// A Compass run by what it was like, not by the mode's menu name ("Budget
/// Agent", "Gamifier"), which means nothing in a sentence about the reader.
private func compassRun(_ mode: WonderConciergeMode?, token: String) -> (label: String, clause: String) {
    switch mode {
    case .closeToHome?: return ("close-to-home Compass runs", "you went on a Compass run close to home")
    case .budget?: return ("Compass runs that cost next to nothing", "you went on a Compass run that cost next to nothing")
    case .obscure?: return ("odd-corner Compass runs", "you went on a Compass run to an odd forgotten corner")
    case .vibe?: return ("Compass runs that matched your mood", "you went on a Compass run that matched your mood")
    case .scavenger?: return ("treasure-hunt Compass runs", "you went on a Compass run that was a treasure hunt")
    case .recovery?: return ("resting Compass runs", "you went on a Compass run where resting counted")
    case nil:
        let name = spacedWords(token).lowercased()
        return ("\(name) Compass runs", "you went on \(withArticle(name)) Compass run")
    }
}

private func compassPlace(_ place: CompassPlaceContext?, token: String) -> (label: String, clause: String) {
    switch place {
    case .current?: return ("Compass runs right where you were", "your Compass run stayed right where you were")
    case .home?: return ("Compass runs at home", "your Compass run stayed at home")
    case .work?: return ("Compass runs at work", "your Compass run happened at work")
    case .cafe?: return ("Compass runs to a cafe", "your Compass run took you to a cafe")
    case .harbor?: return ("Compass runs to the harbour", "your Compass run took you to the harbour")
    case .park?: return ("Compass runs to a park", "your Compass run took you to a park")
    case .store?: return ("Compass runs to a shop", "your Compass run took you to a shop")
    case .library?: return ("Compass runs to a library", "your Compass run took you to a library")
    case .transit?: return ("Compass runs on a train or bus", "your Compass run took you on a train or bus")
    case .waterfront?: return ("Compass runs down to the water", "your Compass run took you down to the water")
    case .trail?: return ("Compass runs along a trail", "your Compass run took you along a trail")
    case .neighborhood?: return ("Compass runs round your own streets", "your Compass run went round your own streets")
    case .indoors?: return ("Compass runs indoors", "your Compass run stayed indoors")
    case .other?: return ("Compass runs somewhere else", "your Compass run went somewhere else")
    case nil:
        let name = spacedWords(token).lowercased()
        return ("Compass runs to \(name)", "your Compass run went to \(name)")
    }
}

/// What the reader's photographs and voice were like, said the way a child
/// would say it about a picture or a voice. Returns nil for a value it can't
/// say plainly: a quality nobody can read is not worth counting out loud.
private func sensoryWords(
    _ dimension: SensoryObservation.Dimension,
    value: String
) -> (label: String, clause: String)? {
    switch dimension {
    case .modality:
        switch value {
        case "words": return ("written Pages", "your Page was written in words")
        case "photo": return ("photo Pages", "your Page had a photo on it")
        case "voice": return ("spoken Pages", "your Page was said out loud")
        case "place": return ("place Pages", "your Page was about a place")
        case "weather": return ("weather Pages", "your Page was about the weather")
        default: return nil
        }
    case .subject:
        // My eye names what it sees in a picture with one word, and I say it
        // as that word rather than pretending to know "a dog" from "dogs".
        return ("“\(value)” in your photos", "I spotted “\(value)” in your photo")
    case .palette:
        return ("\(value) photos", "your photo came out \(value)")
    case .brightness:
        let light = value.contains("light") ? value : "\(value) light"
        return ("photos in \(light)", "your photo was taken in \(light)")
    case .composition:
        // Stored as "landscape, people-0".
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let shapes = ["landscape": "wide", "portrait": "tall", "square": "square"]
        guard let shape = parts.first.flatMap({ shapes[$0] }),
              let people = parts.dropFirst().first(where: { $0.hasPrefix("people-") })
                .flatMap({ Int($0.dropFirst("people-".count)) }) else { return nil }
        let who = people == 0 ? "nobody" : (people == 1 ? "one person" : "\(people) people")
        return ("\(shape) photos with \(who) in them", "your photo was \(shape) with \(who) in it")
    case .voiceCadence:
        let how = [
            "sparse fragments": "in little bits", "short bursts": "in quick bursts",
            "long-paused phrases": "with long stops in between", "continuous flow": "without stopping",
            "measured phrases": "slowly and steadily"
        ][value]
        guard let how else { return nil }
        return ("talking to me \(how)", "you talked to me \(how)")
    case .voiceEnergy:
        let how = [
            "hushed": "quietly", "high contrast": "loud and soft by turns",
            "varied": "up and down", "even": "evenly"
        ][value]
        guard let how else { return nil }
        return ("talking to me \(how)", "you talked to me \(how)")
    default:
        return nil
    }
}

/// The composite body score, as something a child would say about a body.
/// It folds sleep, movement and energy together, so it can say "tired" and
/// nothing about why.
private func bodyWords(_ value: Int) -> (id: String, state: String) {
    if value <= 33 { return ("low", "tired") }
    if value >= 67 { return ("high", "full of beans") }
    return ("middling", "doing all right")
}

// MARK: - The world around the Page

/// Weather, hour, place. The cheapest facts there are, and the ones the reader
/// never had to type.
enum WorldConditionsProjector: LoomProjector {
    static let id = "world"
    static let domains = ["hour", "weather", "place", "placeKind"]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard let context = page.context else { return [] }
        return features(for: context)
    }

    static func features(for context: BookPageContextSnapshot) -> [LoomFeatureRef] {
        var out: [LoomFeatureRef] = []
        if ["morning", "afternoon", "evening", "night"].contains(context.dayPart) {
            let part = context.dayPart
            let when = part == "night" ? "at night" : "in the \(part)"
            out.append(LoomFeatureRef(
                id: "hour:\(part)", domain: "hour", label: "\(part)s",
                conditionClause: "it was \(part)", outcomeClause: "you came to me \(when)",
                symbolName: "clock", role: .conditionOnly, rank: 15
            ))
        }
        for tag in context.weatherTags.prefix(3) {
            let weather = weatherClauses(tag)
            out.append(LoomFeatureRef(
                id: "weather:\(tag)", domain: "weather", label: weather.label,
                conditionClause: weather.condition,
                outcomeClause: weather.outcome,
                symbolName: "cloud", role: .conditionOnly, rank: 10
            ))
        }
        let placeLabel = context.locationLabel?.nonEmpty ?? context.nearbyAnchorID?.nonEmpty
        // "Current place" is what a row says when it does not know where you
        // were. It is not somewhere you went.
        if let place = placeLabel, place.lowercased() != "current place" {
            let name = context.locationLabel?.nonEmpty.map(humanised) ?? anchorName(place)
            out.append(LoomFeatureRef(
                id: "place:\(place.lowercased())", domain: "place", label: name,
                conditionClause: "you were at \(name)",
                outcomeClause: "you went to \(name)",
                symbolName: "mappin", role: .either, rank: 25
            ))
        }
        // What *kind* of place it was, which is the half the Book could never
        // reach before: a place feature keyed on an Anchor id says "you write
        // differently at anchor-7f3a", and only a taxonomy can say "you write
        // differently near water".
        if let kind = context.placeKind?.nonEmpty {
            let place = withArticle(placeKindWords(kind))
            out.append(LoomFeatureRef(
                id: "place-kind:\(kind)", domain: "placeKind", label: place,
                conditionClause: "you were at \(place)",
                outcomeClause: "you went to \(place)",
                symbolName: "mappin.and.ellipse", role: .either, rank: 24
            ))
        }
        // A real category outranks the name. "Waterloo Road" is not water, and a
        // beach the reader called "the quiet end" is. Pages kept before the
        // taxonomy arrived carry no kind, so they keep the older reading rather
        // than silently losing it.
        let isWater = context.placeKind.map { PlaceKind.waterKinds.contains($0) }
            ?? placeLabel.map(isWaterPlace)
            ?? false
        if isWater { out.append(waterFeature()) }
        return out
    }
}

/// The shape of the day itself, and whether the reader showed up.
///
/// `writing` is the important one here. Until there was a feature for *a day
/// happened*, every correspondence was secretly conditioned on the reader
/// having opened the Book, which is the one condition that bends everything.
enum DayShapeProjector: LoomProjector {
    static let id = "day-shape"
    static let domains = ["weekPart", "season", "writing"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        var out = temporalFeatures(at: day.date, in: slice)
        let wrote = day.capturedPages.contains { $0.readerAuthoredTextForAnalysis != nil }
        out.append(writingFeature(wrote))
        return out
    }

    static func features(forDaybook entry: DaybookEntry, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        var out = temporalFeatures(at: entry.date, in: slice)
        let wrote = (entry.medianWordsWritten ?? 0) > 0 || entry.keptPageCount > 0
        out.append(writingFeature(wrote))
        return out
    }

    static func temporalFeatures(at date: Date, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        var out: [LoomFeatureRef] = []
        let weekday = slice.calendar.component(.weekday, from: date)
        let part = (weekday == 1 || weekday == 7) ? "the weekend" : "a weekday"
        out.append(LoomFeatureRef(
            id: "week:\(part)", domain: "weekPart", label: part == "the weekend" ? "weekends" : "weekdays",
            conditionClause: "it was \(part)", outcomeClause: "it was \(part)",
            symbolName: "calendar", role: .conditionOnly, rank: 20
        ))
        let index = GrimoireDay.index(for: date, calendar: slice.calendar)
        let season = GrimoireVoice.seasonName(GrimoireDay.season(of: index))
        out.append(LoomFeatureRef(
            id: "season:\(season)", domain: "season", label: season,
            conditionClause: "it was \(season)", outcomeClause: "it was \(season)",
            symbolName: "leaf", role: .conditionOnly, rank: 12
        ))
        return out
    }

    private static func writingFeature(_ wrote: Bool) -> LoomFeatureRef {
        LoomFeatureRef(
            id: wrote ? "writing:kept" : "writing:quiet",
            domain: "writing", label: wrote ? "days you wrote" : "days you didn't write",
            conditionClause: wrote ? "you wrote something" : "you didn't write anything",
            outcomeClause: wrote ? "you wrote something" : "you didn't write anything",
            symbolName: "pencil", role: .either, provenance: .readerAuthored, rank: 68
        )
    }
}

// MARK: - What the reader did

/// The keep decision, and what was kept.
///
/// Keeping is the densest honest outcome the Book has: it is a judgement the
/// reader actually made, and it needs no new instrumentation at all. It is weak
/// evidence for *you felt alive* and strong evidence for *this one mattered*.
enum KeptPageProjector: LoomProjector {
    static let id = "kept"
    static let domains = ["pageKind", "media", "ink"]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        var out: [LoomFeatureRef] = [
            LoomFeatureRef(
                id: "kept:\(page.type.rawValue)", domain: "pageKind", label: "\(page.type.shortTitle) Pages",
                conditionClause: "you kept \(withArticle(page.type.shortTitle)) Page",
                outcomeClause: "you kept \(withArticle(page.type.shortTitle)) Page",
                symbolName: page.type.symbolName, role: .outcomeOnly,
                provenance: .readerAuthored, rank: 70
            )
        ]
        if page.hasReaderPhotograph {
            out.append(LoomFeatureRef(
                id: "media:photograph", domain: "media", label: "photos",
                conditionClause: "you took a photo",
                outcomeClause: "you kept a photo",
                symbolName: "camera", role: .either, provenance: .readerAuthored, rank: 72
            ))
        }
        if page.hasReaderAudioRecording {
            out.append(LoomFeatureRef(
                id: "media:voice", domain: "media", label: "talking to me out loud",
                conditionClause: "you talked to me out loud",
                outcomeClause: "you talked to me out loud",
                symbolName: "waveform", role: .either, provenance: .readerAuthored, rank: 72
            ))
        }
        if let text = page.readerAuthoredTextForAnalysis {
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            let weight = words >= 90 ? "heavy" : (words >= 30 ? "steady" : "light")
            // The ink is mine, and it notices how far it got to go.
            let ink = weight == "heavy" ? ("lots of ink", "lots of my ink")
                : (weight == "steady" ? ("some ink", "a fair bit of my ink") : ("a drop of ink", "only a drop of my ink"))
            out.append(LoomFeatureRef(
                id: "ink:\(weight)", domain: "ink", label: ink.0,
                conditionClause: "you used \(ink.1)",
                outcomeClause: "you used \(ink.1)",
                symbolName: "drop", role: .outcomeOnly, provenance: .readerAuthored, rank: 69
            ))
        }
        return out
    }
}

/// The reader's own vocabulary.
///
/// Only words in the reader's own hand ever get here, which is what makes
/// "indoor Compass Runs bring back the word *fun*" a real finding rather than
/// the Book noticing its own prompt.
enum ReaderWordsProjector: LoomProjector {
    static let id = "words"
    static let domains = ["word"]

    /// Words too common to mean anything. Kept short on purpose: the contrast
    /// test throws out ordinary words on its own, and a long hand-tuned list is
    /// how you accidentally forbid the Book from noticing something true.
    static let ignored: Set<String> = [
        "the", "and", "for", "that", "this", "with", "from", "into", "was",
        "were", "are", "had", "has", "have", "not", "but", "you", "your",
        "our", "out", "one", "all", "off", "its", "got", "get", "did", "can",
        "now", "how", "who", "why", "too", "any", "own", "she", "her", "him",
        "his", "way", "yet", "may", "say", "lot", "bit",
        "about", "after", "again", "there", "their", "these", "those", "which",
        "would", "could", "should", "where", "while", "being", "doing", "going",
        "thing", "things", "really", "little", "still", "today", "tomorrow",
        "yesterday", "because", "through", "before", "always", "never", "every"
    ]

    static let perPage = 5

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard let text = page.readerAuthoredTextForAnalysis?.lowercased() else { return [] }
        var seen = Set<String>()
        var out: [LoomFeatureRef] = []
        for raw in text.split(whereSeparator: { !$0.isLetter }) {
            guard out.count < perPage else { break }
            let word = String(raw)
            guard word.count >= 3, !ignored.contains(word), !seen.contains(word) else { continue }
            // The same curated lists the threads use. Without them a sim Book
            // held 2,920 word rules, led by "over", "down", "all" and "kept".
            guard !LiteraryContinuityProjector.stopWords.contains(word),
                  !LiteraryContinuityProjector.weakLiterarySubjects.contains(word) else { continue }
            seen.insert(word)
            out.append(LoomFeatureRef(
                id: "word:\(word)", domain: "word", label: "the word “\(word)”",
                conditionClause: "you used the word “\(word)”",
                outcomeClause: "you used the word “\(word)”",
                symbolName: "text.quote", role: .either, provenance: .readerAuthored, rank: 60
            ))
        }
        return out
    }
}

/// Cast, choices, and story shapes, read off the typed tags.
///
/// The standing rule holds: a Page the Book wrote may lend the reader's
/// *observable act* — met, chose, kept — but never its prose. Everything here
/// is an act, which is why it is `systemEvent` and not `generatedFiction`.
enum StoryTagProjector: LoomProjector {
    static let id = "story-tags"
    static let domains = ["cast", "choice", "genre", "storyForm"]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        page.tags.prefix(12).compactMap { raw -> LoomFeatureRef? in
            let tag = raw.lowercased()
            func value(after prefix: String) -> String? {
                guard tag.hasPrefix(prefix) else { return nil }
                return String(tag.dropFirst(prefix.count)).nonEmpty
            }
            /// The same token with its capitals, which a squashed choice id
            /// needs to find its word boundaries again.
            func original(after prefix: String) -> String {
                String(raw.dropFirst(prefix.count))
            }
            if let token = value(after: "sender:") ?? value(after: "entity:") {
                let name = BleedDayDesk.castName(token)
                return LoomFeatureRef(
                    id: "cast:\(token)", domain: "cast", label: name,
                    conditionClause: "\(name) was around",
                    outcomeClause: "\(name) came to see you",
                    symbolName: "person.crop.rectangle.stack",
                    role: .either, provenance: .systemEvent, rank: 60
                )
            }
            if let token = value(after: "choice:") {
                let name = "“\(BookPage.humanizedChoice(original(after: "choice:")))”"
                return LoomFeatureRef(
                    id: "choice:\(token)", domain: "choice", label: name,
                    conditionClause: "you picked \(name)",
                    outcomeClause: "you picked \(name)",
                    symbolName: "arrow.triangle.branch",
                    role: .either, provenance: .systemEvent, rank: 75
                )
            }
            if let token = value(after: "genre:") {
                let name = genreName(token)
                return LoomFeatureRef(
                    id: "genre:\(token)", domain: "genre", label: "\(name) stories",
                    conditionClause: "the story was \(withArticle(name))",
                    outcomeClause: "you picked \(withArticle(name)) story",
                    symbolName: "books.vertical",
                    role: .either, provenance: .systemEvent, rank: 75
                )
            }
            if let token = value(after: "form:") {
                let name = formName(token)
                return LoomFeatureRef(
                    id: "story-form:\(token)", domain: "storyForm", label: "stories shaped like \(name)",
                    conditionClause: "the story was shaped like \(name)",
                    outcomeClause: "you picked a story shaped like \(name)",
                    symbolName: "text.book.closed",
                    role: .either, provenance: .systemEvent, rank: 75
                )
            }
            return nil
        }
    }
}

/// Real people. Marked sensitive, so nothing here reaches ordinary speech
/// without the Witness Law being applied on purpose.
enum PeopleProjector: LoomProjector {
    static let id = "people"
    static let domains = ["person"]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard let receipt = page.relationshipReceipt else { return [] }
        guard let name = slice.peopleNames[receipt.personID] else { return [] }
        return [LoomFeatureRef(
            id: "person:\(receipt.personID)", domain: "person", label: name,
            conditionClause: "\(name) was part of the day",
            outcomeClause: "you kept a moment with \(name)",
            symbolName: "person.crop.circle",
            role: .either, sensitivity: .person, provenance: .readerAuthored, rank: 42
        )]
    }
}

/// The reader's own body and weather. Counted, never diagnosed.
///
/// Sensitive by construction: these can be *related* to things, and the numbers
/// are as real as any other, but nothing here is allowed to become a sentence
/// about who the reader is.
enum InnerWeatherProjector: LoomProjector {
    static let id = "inner"
    static let domains = ["body", "sleep"]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard let context = page.context else { return [] }
        var out: [LoomFeatureRef] = []
        if let score = context.bodyScore {
            let body = bodyWords(score)
            out.append(LoomFeatureRef(
                id: "body:\(body.id)", domain: "body", label: "days your body was \(body.state)",
                conditionClause: "your body was \(body.state)",
                outcomeClause: "your body was \(body.state)",
                symbolName: "heart", role: .conditionOnly,
                sensitivity: .innerState, rank: 30
            ))
        }
        if let hours = context.sleepHours {
            let level = hours < 6 ? "short" : (hours > 8 ? "long" : "ordinary")
            let night = level == "short" ? ("short nights", "less than six hours")
                : (level == "long" ? ("long sleeps", "more than eight hours") : ("ordinary nights", "an ordinary amount"))
            out.append(LoomFeatureRef(
                id: "sleep:\(level)", domain: "sleep", label: night.0,
                conditionClause: "you'd slept \(night.1) the night before",
                outcomeClause: "you slept \(night.1)",
                symbolName: "moon.zzz", role: .conditionOnly,
                sensitivity: .innerState, rank: 28
            ))
        }
        return out
    }
}

/// Which Fae were about, and which of their bargains the reader actually kept.
///
/// This is what makes "the Salamanders come out when it rains at night" and
/// "this species has been good to you" askable at all: a species becomes a
/// condition, and keeping its bargain becomes an outcome the reader chose.
enum FaeEncounterProjector: LoomProjector {
    static let id = "fae"
    static let domains = ["fae", "faeKept"]
    static let dayScope: LoomProjectorDayScope = .event

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        page.tags.compactMap { raw in
            let tag = raw.lowercased()
            guard tag.hasPrefix("fae:"), let token = String(tag.dropFirst(4)).nonEmpty else { return nil }
            let kind = FaeKind.allCases.first { $0.rawValue.lowercased() == token }
            let stable = kind?.rawValue ?? token
            let name = kind?.name ?? humanised(token)
            return LoomFeatureRef(
                id: "fae:\(stable)", domain: "fae", label: name,
                conditionClause: "\(name) was around", outcomeClause: "\(name) came to see you",
                symbolName: "sparkles", role: .either,
                provenance: .systemEvent, rank: 58
            )
        }
    }

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.faeBargains.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for bargain in slice.faeBargains {
            let kind = bargain.faeKind
            if GrimoireDay.index(for: bargain.offeredAt, calendar: slice.calendar) == index,
               seen.insert("met:\(kind.rawValue)").inserted {
                out.append(LoomFeatureRef(
                    id: "fae:\(kind.rawValue)", domain: "fae", label: kind.name,
                    conditionClause: "\(kind.name) was around",
                    outcomeClause: "\(kind.name) came to see you",
                    symbolName: "sparkles", role: .either,
                    provenance: .systemEvent, rank: 58
                ))
            }
            if let deliveredAt = bargain.deliveredAt,
               GrimoireDay.index(for: deliveredAt, calendar: slice.calendar) == index,
               seen.insert("kept:\(kind.rawValue)").inserted {
                out.append(LoomFeatureRef(
                    id: "fae-kept:\(kind.rawValue)", domain: "faeKept",
                    label: "bargains with \(kind.name)",
                    conditionClause: "you kept your side of a bargain with \(kind.name)",
                    outcomeClause: "you kept your side of a bargain with \(kind.name)",
                    symbolName: "hand.raised.fill", role: .outcomeOnly,
                    provenance: .readerAuthored, rank: 71
                ))
            }
        }
        return out
    }
}

/// Workings set, and Workings the reader actually came back from.
///
/// The return is the interesting half. A Working that was set and never
/// answered is a different thing from one that brought something back, and only
/// the second is evidence about the reader.
enum WorkingProjector: LoomProjector {
    static let id = "workings"
    /// Its own event, like a Fae bargain. A Working resolving on the same date
    /// as something unrelated is a coincidence of the calendar, not a shared
    /// occasion, and must not corroborate it.
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["working", "workingInitiator", "workingEpisode", "workingOutcome"]

    /// A Working is an *episode*, not a day.
    ///
    /// It is set on one day and resolves on another, often a fortnight later —
    /// so recording "an unnecessary route was set" and "something came back"
    /// as two unrelated days meant the two halves could never be compared. The
    /// comparison the engine exists for, *these Workings bring something back
    /// and those ones do not*, could not fire on real data at all.
    ///
    /// On the day it resolves, both halves are laid down together: which kind
    /// of Working it was, who set it, and how it ended. The outcome is
    /// deliberately recipe-agnostic, because a shared outcome is the only thing
    /// two recipes can be measured against.
    ///
    /// "Came back at all" is the honest proxy for the original wish, which was
    /// "came back with *better* souvenirs". The Book has no measure of better.
    /// Every Working is set by the Book or by a character — never by the reader
    /// on their own — so a Working resolving is always something the Book
    /// arranged, whoever eventually walked out of the door.
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        !features(forDay: day, in: slice).isEmpty
    }

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.workings.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()

        func initiator(_ working: BookWorking) -> LoomFeatureRef? {
            let name = working.initiatorName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert("by:\(working.initiatorID)").inserted else { return nil }
            // I'm the one talking, so I never call myself the Book.
            let mine = working.initiatorKind == .book
            return LoomFeatureRef(
                id: "working-by:\(working.initiatorID)", domain: "workingInitiator",
                label: mine ? "the things I set you myself" : name,
                conditionClause: mine ? "I set you something myself" : "\(name) set you something",
                outcomeClause: mine ? "I set you something myself" : "\(name) set you something",
                symbolName: "person.wave.2", role: .conditionOnly,
                provenance: .systemEvent, rank: 59
            )
        }

        for working in slice.workings {
            let recipe = errand(working)

            if GrimoireDay.index(for: working.createdAt, calendar: slice.calendar) == index {
                if seen.insert("set:\(working.recipeID)").inserted {
                    out.append(LoomFeatureRef(
                        id: "working:\(working.recipeID)", domain: "working", label: recipe.many,
                        conditionClause: "\(recipe.one) was waiting for you",
                        outcomeClause: "you took on \(recipe.one)",
                        symbolName: "wand.and.stars", role: .either,
                        provenance: .systemEvent, rank: 62
                    ))
                }
                if let by = initiator(working) { out.append(by) }
            }

            // How it ended, and on which day that was settled.
            let ending: (day: Date, id: String, label: String, clause: String, reader: Bool)?
            switch working.status {
            case .returned:
                ending = working.returnedAt.map {
                    ($0, "returned", "coming back to tell me", "you came back and told me how it went", true)
                }
            case .elapsed:
                ending = (working.endsAt, "lapsed", "letting it run out", "you let it run out", false)
            case .cancelled:
                ending = (working.endsAt, "dropped", "putting it down", "you put it down", false)
            case .prepared, .arranged:
                ending = nil
            }
            guard let ending,
                  GrimoireDay.index(for: ending.day, calendar: slice.calendar) == index else { continue }

            if seen.insert("episode:\(working.recipeID)").inserted {
                out.append(LoomFeatureRef(
                    id: "working-episode:\(working.recipeID)", domain: "workingEpisode",
                    label: recipe.many,
                    conditionClause: "\(recipe.one) came to an end",
                    outcomeClause: "\(recipe.one) came to an end",
                    symbolName: "wand.and.stars", role: .either,
                    provenance: .systemEvent, rank: 61
                ))
            }
            if let by = initiator(working) { out.append(by) }
            if seen.insert("outcome:\(ending.id)").inserted {
                out.append(LoomFeatureRef(
                    id: "working-outcome:\(ending.id)", domain: "workingOutcome",
                    label: ending.label,
                    conditionClause: ending.clause,
                    outcomeClause: ending.clause,
                    symbolName: ending.reader ? "arrow.uturn.backward" : "hourglass",
                    role: .outcomeOnly,
                    // Coming back is the reader's own act. Letting a thing
                    // lapse is the calendar's.
                    provenance: ending.reader ? .readerAuthored : .systemEvent,
                    rank: 73
                ))
            }
        }
        return out
    }
}

/// Which kind of Compass run the reader actually went on.
///
/// A run leaves a `.wonderCompass` Page tagged `concierge:<mode>`, which is a
/// real dated receipt of a real outing — the strongest kind of evidence the
/// Book has, because the reader had to leave the Book to make it. `Compass Run`
/// as a bare page type was already counted; this is what lets the Book tell one
/// sort of expedition from another.
enum CompassRunProjector: LoomProjector {
    static let id = "compass"
    static let domains = ["compass", "compassPlace", "placeKind"]

    private static let prefix = "concierge:"

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard page.type == .wonderCompass else { return [] }
        return page.tags.compactMap { raw -> LoomFeatureRef? in
            let tag = raw.lowercased()
            if tag.hasPrefix(prefix), let token = String(tag.dropFirst(prefix.count)).nonEmpty {
                let mode = WonderConciergeMode.allCases.first { $0.rawValue.lowercased() == token }
                let stable = mode?.rawValue ?? token
                let run = compassRun(mode, token: token)
                return LoomFeatureRef(
                    id: "compass:\(stable)", domain: "compass", label: run.label,
                    conditionClause: run.clause,
                    outcomeClause: run.clause,
                    symbolName: "location.north.circle", role: .either,
                    provenance: .readerAuthored, rank: 40
                )
            }
            if tag.hasPrefix("compass-place:"), let token = String(tag.dropFirst(14)).nonEmpty {
                let place = CompassPlaceContext.allCases.first { $0.rawValue.lowercased() == token }
                let stable = place?.rawValue ?? token
                let run = compassPlace(place, token: token)
                return LoomFeatureRef(
                    id: "compass-place:\(stable)", domain: "compassPlace", label: run.label,
                    conditionClause: run.clause,
                    outcomeClause: run.clause,
                    symbolName: "mappin.and.ellipse", role: .either,
                    provenance: .readerAuthored, rank: 35
                )
            }
            if tag == "place-kind:water" { return waterFeature() }
            return nil
        }
    }
}

// MARK: - The raw day and the reader's explicit answer

enum DaybookProjector: LoomProjector {
    static let id = "daybook"
    static let domains = ["weather", "place", "placeKind", "travel", "calendarLoad", "readerState", "daylight"]

    static func features(forDaybook entry: DaybookEntry, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard entry.carriesEvidence else { return [] }
        var out: [LoomFeatureRef] = []
        for tag in entry.weatherTags.prefix(3) {
            let weather = weatherClauses(tag)
            out.append(LoomFeatureRef(
                id: "weather:\(tag)", domain: "weather", label: weather.label,
                conditionClause: weather.condition,
                outcomeClause: weather.outcome,
                symbolName: "cloud", role: .conditionOnly, rank: 10
            ))
        }
        if let place = entry.placeLabel?.nonEmpty ?? entry.nearbyAnchorID?.nonEmpty {
            let name = entry.placeLabel?.nonEmpty.map(humanised) ?? anchorName(place)
            out.append(LoomFeatureRef(
                id: "place:\(place.lowercased())", domain: "place", label: name,
                conditionClause: "you were at \(name)", outcomeClause: "you went to \(name)",
                symbolName: "mappin", role: .either, rank: 25
            ))
            if isWaterPlace(place) { out.append(waterFeature()) }
        }
        if let minutes = entry.daylightMinutes {
            // How much light the day actually had. Banded, because the Book is
            // asking whether the dark half of the year changes the reader, not
            // counting minutes at them.
            let band = minutes >= 13 * 60 ? "long" : (minutes <= 9 * 60 ? "short" : "even")
            // The sun keeps hours like anybody else.
            let sun = band == "long" ? ("days the sun stays up late", "the sun stayed up late")
                : (band == "short" ? ("days the sun goes to bed early", "the sun went to bed early")
                    : ("days the sun keeps ordinary hours", "the sun kept ordinary hours"))
            out.append(LoomFeatureRef(
                id: "daylight:\(band)", domain: "daylight", label: sun.0,
                conditionClause: sun.1,
                outcomeClause: sun.1,
                symbolName: "sun.horizon", role: .conditionOnly, rank: 12
            ))
        }
        if let travelled = entry.travelled {
            out.append(LoomFeatureRef(
                id: travelled ? "travel:moved" : "travel:stayed",
                domain: "travel", label: travelled ? "travelling days" : "days you stayed close to home",
                conditionClause: travelled ? "you travelled" : "you stayed close to home",
                outcomeClause: travelled ? "you travelled" : "you stayed close to home",
                symbolName: "figure.walk", role: .either, rank: 32
            ))
        }
        if let events = entry.calendarEventCount {
            let load = events == 0 ? "open" : (events >= 4 ? "crowded" : "occupied")
            let diary = load == "open" ? ("empty-calendar days", "your calendar was empty")
                : (load == "crowded" ? ("packed days", "your calendar was packed")
                    : ("days with a few things on", "your calendar had a few things on it"))
            out.append(LoomFeatureRef(
                id: "calendar-load:\(load)", domain: "calendarLoad", label: diary.0,
                conditionClause: diary.1, outcomeClause: diary.1,
                symbolName: "calendar", role: .conditionOnly, rank: 18
            ))
        }
        out.append(contentsOf: ReaderStateProjector.features(
            aliveness: entry.alivenessScore,
            wonder: entry.wonderScore,
            hiddenMagic: entry.hiddenMagicScore
        ))
        return out
    }
}

enum ReaderStateProjector: LoomProjector {
    static let id = "reader-state"
    static let domains = ["readerState"]

    static func features(forPulse pulse: ReaderStatePulseRecord, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        switch pulse.dimension {
        case .aliveness: return features(aliveness: pulse.score, wonder: nil, hiddenMagic: nil)
        case .wonder: return features(aliveness: nil, wonder: pulse.score, hiddenMagic: nil)
        case .hiddenMagic: return features(aliveness: nil, wonder: nil, hiddenMagic: pulse.score)
        case .delayedOutcome: return pulse.score >= 7 ? [brightMomentFeature()] : []
        case .capacity: return []
        }
    }

    static func features(aliveness: Int?, wonder: Int?, hiddenMagic: Int?) -> [LoomFeatureRef] {
        var out: [LoomFeatureRef] = []
        if let aliveness, aliveness >= 7 {
            out.append(LoomFeatureRef(
                id: "reader-state:alive", domain: "readerState", label: "feeling more alive",
                conditionClause: "you told me you felt more alive",
                outcomeClause: "you told me you felt more alive",
                symbolName: "sparkles", role: .outcomeOnly,
                sensitivity: .readerReported, provenance: .readerAuthored, rank: 82
            ))
            out.append(brightMomentFeature())
        }
        if let wonder, wonder >= 7 {
            out.append(LoomFeatureRef(
                id: "reader-state:wonder", domain: "readerState", label: "lots of wonder",
                conditionClause: "you told me you felt lots of wonder",
                outcomeClause: "you told me you felt lots of wonder",
                symbolName: "eyes", role: .outcomeOnly,
                sensitivity: .readerReported, provenance: .readerAuthored, rank: 82
            ))
            out.append(brightMomentFeature())
        }
        if let hiddenMagic, hiddenMagic >= 7 {
            out.append(LoomFeatureRef(
                id: "reader-state:hidden-magic", domain: "readerState", label: "magic feeling close",
                conditionClause: "you told me magic felt close",
                outcomeClause: "you told me magic felt close",
                symbolName: "wand.and.stars", role: .outcomeOnly,
                sensitivity: .readerReported, provenance: .readerAuthored, rank: 82
            ))
            out.append(brightMomentFeature())
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }

    private static func brightMomentFeature() -> LoomFeatureRef {
        LoomFeatureRef(
            id: "reader-state:bright-moment", domain: "readerState", label: "bright moments",
            conditionClause: "you told me about a bright moment",
            outcomeClause: "you told me about a bright moment",
            symbolName: "sun.max", role: .outcomeOnly,
            sensitivity: .readerReported, provenance: .readerAuthored, rank: 84
        )
    }
}

private func waterFeature() -> LoomFeatureRef {
    LoomFeatureRef(
        id: "place-kind:water", domain: "placeKind", label: "water",
        conditionClause: "you were near water", outcomeClause: "you went near water",
        symbolName: "water.waves", role: .either, rank: 22
    )
}

private func isWaterPlace(_ value: String) -> Bool {
    let lower = value.lowercased()
    return ["water", "harbor", "harbour", "river", "lake", "ocean", "beach", "marina", "pier", "shore", "canal", "creek"]
        .contains { lower.contains($0) }
}

/// What the reader's own photographs and voice were like.
///
/// The Book already derives a sensory folio for kept media; this lets those
/// qualities become half of a correspondence — a palette that keeps arriving
/// with a place, a voice cadence that keeps arriving with an hour.
///
/// Gated exactly as the older Loom gates it: only the reader's own hand or the
/// reader's own media. A photograph the Book generated describes the Book.
enum SensoryProjector: LoomProjector {
    static let id = "sensory"
    static let domains = [
        "modality", "subject",
        "visualPalette", "visualBrightness", "visualComposition",
        "voiceCadence", "voiceEnergy"
    ]

    private static let lanes: [(SensoryObservation.Dimension, String, String, String)] = [
        (.modality, "modality", "Medium", "square.stack.3d.up"),
        (.subject, "subject", "Subject", "bookmark"),
        (.palette, "visualPalette", "Photographic palette", "paintpalette"),
        (.brightness, "visualBrightness", "Photographic light", "sun.max"),
        (.composition, "visualComposition", "Composition", "viewfinder"),
        (.voiceCadence, "voiceCadence", "Voice cadence", "waveform"),
        (.voiceEnergy, "voiceEnergy", "Voice energy", "waveform.path")
    ]

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard page.origin == .userAuthored
                || page.hasReaderPhotograph
                || page.hasReaderAudioRecording else { return [] }
        let folio = page.resolvedSensoryFolio
        var out: [LoomFeatureRef] = []
        for (dimension, domain, _, symbol) in lanes {
            for value in folio.values(for: dimension) {
                let token = value.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                guard !token.isEmpty else { continue }
                guard let words = sensoryWords(dimension, value: value.lowercased()) else { continue }
                out.append(LoomFeatureRef(
                    id: "\(domain):\(token)", domain: domain,
                    label: words.label,
                    conditionClause: words.clause,
                    outcomeClause: words.clause,
                    symbolName: symbol, role: .either,
                    provenance: .readerAuthored, rank: 85
                ))
            }
        }
        return out
    }
}

/// The threads the Book has already named, marked onto the Pages that carry them.
///
/// Nothing is re-derived here: the semantic work happens in the continuity
/// digest, and this only records which of the reader's own Pages a thread
/// touched, so a subject can stand on either side of a correspondence.
enum MeaningProjector: LoomProjector {
    static let id = "meaning"
    static let domains = ["meaning"]

    static let perPage = 16

    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        // Only the reader's own writing may carry a thread as evidence about
        // the reader. A generated scene mentioning the harbour is the Book
        // talking to itself.
        guard page.readerAuthoredTextForAnalysis != nil else { return [] }
        return slice.continuity.strongestSignals.prefix(perPage).compactMap { signal in
            guard signal.evidencePageIDs.contains(page.id) else { return nil }
            // A thread founded by counting one word is that word wearing a
            // coat: "Against" arrived beside the word "against" as a finding.
            // The words projector already has the word itself.
            guard signal.kind != .pattern, signal.kind != .absence,
                  !signal.id.hasPrefix("manner-hour-") else { return nil }
            let token = signal.id.lowercased().replacingOccurrences(of: " ", with: "-")
            guard !token.isEmpty else { return nil }
            return LoomFeatureRef(
                id: "meaning:\(token)", domain: "meaning", label: signal.subjectName,
                conditionClause: "you were writing about \(signal.subjectName)",
                outcomeClause: "you wrote about \(signal.subjectName) again",
                symbolName: "point.3.connected.trianglepath.dotted",
                role: .either, provenance: .readerAuthored, rank: 52
            )
        }
    }
}

/// What the moon was doing.
///
/// The cheapest condition there is — a pure function of the date, needing no
/// receipt and no instrumentation — and the one most likely to be worth having
/// in a Book about enchantment. Banded to four quarters: the Book is asking
/// whether the reader changes with the moon, not keeping an ephemeris.
enum MoonProjector: LoomProjector {
    static let id = "moon"
    static let domains = ["moon"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        let phase = MoonPhaseCalendar.phase(on: day.date)
        let band: String
        switch phase.illuminatedFraction {
        case ..<0.15: band = "dark"
        case ..<0.45: band = "thin"
        case ..<0.85: band = "half"
        default: band = "full"
        }
        // The moon is somebody, and it has moods.
        let moon: (label: String, clause: String)
        switch band {
        case "dark": moon = ("nights the moon hides", "the moon was hiding")
        case "thin": moon = ("thin-moon nights", "the moon was a thin little slice")
        case "half": moon = ("half-moon nights", "the moon was only half there")
        default: moon = ("full-moon nights", "the moon was big and round")
        }
        return [LoomFeatureRef(
            id: "moon:\(band)", domain: "moon", label: moon.label,
            conditionClause: moon.clause,
            outcomeClause: moon.clause,
            symbolName: phase.symbolName, role: .conditionOnly,
            provenance: .observedContext, rank: 11
        )]
    }
}

/// Talisman errands, and whether the reader actually went and did them.
///
/// An errand is asked on one day and settled on another, so — like a Working —
/// the day it settles carries both halves: which talisman asked, and whether it
/// was paid. Paying one means leaving the Book and noticing something real,
/// which makes it one of the strongest outcomes the Book has.
enum PactErrandProjector: LoomProjector {
    static let id = "pact-errands"
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["talisman", "errandOutcome"]

    /// A talisman asked; the reader answered. Real, and not free evidence.
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        !features(forDay: day, in: slice).isEmpty
    }

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.pactErrands.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for errand in slice.pactErrands {
            let ending: (day: Date, id: String, label: String, clause: String, reader: Bool)?
            switch errand.status {
            case .delivered:
                ending = errand.deliveredAt.map {
                    ($0, "paid", "doing what a talisman asked", "you did what a talisman asked", true)
                }
            case .lapsed:
                ending = (errand.deadline, "lapsed", "letting a talisman's ask run out", "you let a talisman's ask run out", false)
            case .owed:
                ending = nil
            }
            guard let ending,
                  GrimoireDay.index(for: ending.day, calendar: slice.calendar) == index else { continue }

            let talisman = AcademyChapterRegistry.chapter(forTalismanID: errand.talismanID)
                .map { midSentence($0.talismanName) } ?? "a talisman"
            if seen.insert("by:\(errand.talismanID)").inserted {
                out.append(LoomFeatureRef(
                    id: "talisman:\(errand.talismanID)", domain: "talisman", label: talisman,
                    conditionClause: "\(talisman) asked you for something",
                    outcomeClause: "\(talisman) asked you for something",
                    symbolName: "seal", role: .conditionOnly,
                    provenance: .systemEvent, rank: 57
                ))
            }
            if seen.insert("outcome:\(ending.id)").inserted {
                out.append(LoomFeatureRef(
                    id: "errand-outcome:\(ending.id)", domain: "errandOutcome", label: ending.label,
                    conditionClause: ending.clause,
                    outcomeClause: ending.clause,
                    symbolName: ending.reader ? "checkmark.seal" : "hourglass",
                    role: .outcomeOnly,
                    provenance: ending.reader ? .readerAuthored : .systemEvent,
                    rank: 74
                ))
            }
        }
        return out
    }
}

/// Whether the reader answers when the Book speaks unprompted.
///
/// The Book saying something is not evidence about the reader; the reader
/// *answering* is. It is also the plainest measure of whether they are in the
/// mood for the Book at all, which is a thing worth being able to relate to
/// weather, hour, or anything else.
enum AsideReplyProjector: LoomProjector {
    static let id = "asides"
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["asideReply"]

    /// The Book spoke first. Being answered is a real act and a poor witness.
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        !features(forDay: day, in: slice).isEmpty
    }

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.asideReceipts.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for receipt in slice.asideReceipts {
            guard let answeredAt = receipt.respondedAt, receipt.response != nil else { continue }
            guard GrimoireDay.index(for: answeredAt, calendar: slice.calendar) == index else { continue }
            guard seen.insert("answered").inserted else { continue }
            out.append(LoomFeatureRef(
                id: "aside:answered", domain: "asideReply", label: "answering me back",
                conditionClause: "you answered me back",
                outcomeClause: "you answered me back",
                symbolName: "bubble.left.and.bubble.right",
                role: .either, provenance: .readerAuthored, rank: 66
            ))
        }
        return out
    }
}

/// Real objects pressed into the Book's Pocket.
///
/// Keeping a thing takes reaching for it, which is why this is an outcome and
/// not a circumstance: nobody presses a ticket stub into a book by accident.
enum PocketProjector: LoomProjector {
    static let id = "pocket"
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["pocket"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.pocketKeepsakes.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        guard slice.pocketKeepsakes.contains(where: {
            GrimoireDay.index(for: $0.foundAt, calendar: slice.calendar) == index
        }) else { return [] }
        return [LoomFeatureRef(
            id: "pocket:kept", domain: "pocket", label: "things for my Pocket",
            conditionClause: "you put something in my Pocket",
            outcomeClause: "you put something in my Pocket",
            symbolName: "bag", role: .either,
            provenance: .readerAuthored, rank: 72
        )]
    }
}

/// Jumps into a borrowed story, and what came back out.
///
/// The Book opened the door, so this is something it arranged — but the
/// returning, and the souvenir carried home, is the reader's.
enum BookJumpProjector: LoomProjector {
    static let id = "book-jumps"
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["jumpBook", "jumpOutcome"]

    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        !features(forDay: day, in: slice).isEmpty
    }

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.returnedJumps.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for jump in slice.returnedJumps
        where GrimoireDay.index(for: jump.returnedAt, calendar: slice.calendar) == index {
            if seen.insert("book:\(jump.bookID)").inserted {
                out.append(LoomFeatureRef(
                    id: "jump-book:\(jump.bookID)", domain: "jumpBook", label: jump.title,
                    conditionClause: "you jumped into \(jump.title)",
                    outcomeClause: "you jumped into \(jump.title)",
                    symbolName: "book.closed", role: .either,
                    provenance: .systemEvent, rank: 63
                ))
            }
            let carried = !jump.souvenir.trimmingCharacters(in: .whitespaces).isEmpty
            let key = carried ? "carried" : "empty-handed"
            if seen.insert("out:\(key)").inserted {
                out.append(LoomFeatureRef(
                    id: "jump-outcome:\(key)", domain: "jumpOutcome",
                    label: carried ? "coming back with something" : "coming back empty-handed",
                    conditionClause: carried
                        ? "you came back carrying something"
                        : "you came back empty-handed",
                    outcomeClause: carried
                        ? "you came back carrying something"
                        : "you came back empty-handed",
                    symbolName: carried ? "sparkles" : "hand.raised",
                    role: .outcomeOnly, provenance: .readerAuthored, rank: 75
                ))
            }
        }
        return out
    }
}

/// Observances the Book keeps for the reader.
///
/// The strongest outcome there is — an observance kept is somebody choosing to
/// do a thing again on purpose — and the thinnest data, because only the most
/// recent keeping carries a date. The Book counts what it can honestly see and
/// says nothing about the rest.
enum ObservanceProjector: LoomProjector {
    static let id = "observances"
    static let dayScope: LoomProjectorDayScope = .event
    static let domains = ["observance"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.traditions.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for tradition in slice.traditions {
            guard let kept = tradition.lastObservedAt,
                  GrimoireDay.index(for: kept, calendar: slice.calendar) == index,
                  seen.insert(tradition.kind.rawValue).inserted else { continue }
            let name = tradition.title
            out.append(LoomFeatureRef(
                id: "observance:\(tradition.kind.rawValue)", domain: "observance", label: name,
                conditionClause: "you kept \(name)",
                outcomeClause: "you kept \(name)",
                symbolName: "calendar.badge.checkmark",
                role: .either, provenance: .readerAuthored, rank: 76
            ))
        }
        return out
    }
}

/// What the wheel of the year was doing.
///
/// Free, like the moon: a pure function of the date, needing no receipt. The
/// kind rather than the particular feast, because "you write differently at the
/// sabbats" is a claim worth being able to make and "you write differently on
/// the fourteenth" is noise.
enum AlmanacProjector: LoomProjector {
    static let id = "almanac"
    static let domains = ["almanac"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        let celebrations = LiteraryAlmanac.celebrations(on: day.date, calendar: slice.calendar)
        guard let strongest = celebrations.max(by: { $0.priority < $1.priority }) else { return [] }
        let kind = strongest.kind.rawValue
        // The kind is the Book's filing word ("author", "inWorld"), never a
        // thing to say. Each one gets what the day actually was.
        let days: [String: (label: String, clause: String)] = [
            "author": ("writers' birthdays", "it was a famous writer's birthday"),
            "publication": ("book birthdays", "it was a famous book's birthday"),
            "occult": ("old magicians' days", "it was a day the old magicians wrote something down"),
            "inWorld": ("storybook holidays", "it was a holiday from inside a story"),
            "labyrinth": ("Labyrinth feast days", "it was a feast day in the Labyrinth"),
            "window": ("special sky hours", "the sun made a special hour that day"),
            "first": ("first-of-the-year days", "the weather did something for the first time this year"),
            "family": ("big holidays", "it was a holiday everybody keeps"),
            "birthday": ("birthdays", "it was somebody's birthday"),
            "sabbat": ("old festival days", "it was one of the old festivals on the wheel of the year"),
            "esbat": ("witches' moon nights", "it was a witches' moon night"),
            "shower": ("shooting-star nights", "there were shooting stars that night"),
            "eclipse": ("eclipses", "there was an eclipse")
        ]
        let day = days[kind] ?? ("\(spacedWords(kind)) days", "the almanac marked the day")
        return [LoomFeatureRef(
            id: "almanac:\(kind)", domain: "almanac", label: day.label,
            conditionClause: day.clause,
            outcomeClause: day.clause,
            symbolName: strongest.symbolName, role: .conditionOnly,
            provenance: .observedContext, rank: 14
        )]
    }
}

/// A world event running, and the phase it had reached.
///
/// The Book arranges these, so they are circumstances the reader was inside
/// rather than anything they produced — but a reader who writes differently
/// while the world is in its third act is worth knowing about.
enum WorldEventProjector: LoomProjector {
    static let id = "world-events"
    static let domains = ["worldEvent", "worldEventPhase"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.worldEvents.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        var seen = Set<String>()
        for event in slice.worldEvents {
            let start = GrimoireDay.index(for: event.startedAt, calendar: slice.calendar)
            let end = GrimoireDay.index(for: event.endsAt, calendar: slice.calendar)
            guard index >= start, index <= end else { continue }
            if seen.insert("event:\(event.id)").inserted {
                out.append(LoomFeatureRef(
                    id: "world-event:\(event.id)", domain: "worldEvent", label: event.title,
                    conditionClause: "\(event.title) was going on",
                    outcomeClause: "\(event.title) was going on",
                    symbolName: "sparkles", role: .conditionOnly,
                    provenance: .systemEvent, rank: 22
                ))
            }
            // The dramatic role, not the particular phase id: "the world was
            // building up" is a claim; "the world was in phase-3b" is noise.
            guard let role = event.phase.role else { continue }
            let phase = role.rawValue
            let world: (label: String, clause: String)
            switch role {
            case .setup: world = ("the start of something in the world", "something in the world was just starting")
            case .buildup: world = ("something building up in the world", "something in the world was building up")
            case .climax: world = ("the world's big moments", "something in the world was at its big moment")
            case .aftermath: world = ("the world settling down", "the world was settling down after something big")
            }
            if seen.insert("phase:\(phase)").inserted {
                out.append(LoomFeatureRef(
                    id: "world-event-phase:\(phase)", domain: "worldEventPhase",
                    label: world.label,
                    conditionClause: world.clause,
                    outcomeClause: world.clause,
                    symbolName: "clock.arrow.circlepath", role: .conditionOnly,
                    provenance: .systemEvent, rank: 23
                ))
            }
        }
        return out
    }
}


// MARK: - What the reader did, read off the other ledgers

/// A radio station and the days it was heard, named where the catalogue is.
struct RadioListeningDays: Equatable {
    var stationID: String
    var title: String
    var dayIDs: Set<String>
}

/// Where the reader's attention actually was when a Knock came.
///
/// Experience sampling: the Knock arrives at a time the reader did not choose,
/// so the answer is a measurement rather than a performance. The Book chose
/// only *when*, and at random, which is why this is not marked as asked: the
/// asking cannot bend where the reader's mind already was. A Knock answered
/// with a sentence alone says nothing about where, so it adds nothing here.
enum KnockProjector: LoomProjector {
    static let id = "knocks"
    static let domains = ["attention"]

    static func features(forKnock receipt: AttentionProbeReceipt, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        let answer: (id: String, label: String, clause: String)
        switch receipt.answer {
        case .here:
            answer = ("knock:here", "Knocks that found you right there", "you were right there when I knocked")
        case .elsewhere:
            answer = ("knock:grey", "grey Knocks", "you were somewhere grey when I knocked")
        case .somewhereGood:
            answer = ("knock:somewhere-good", "Knocks that found you somewhere good",
                      "you were somewhere good when I knocked")
        case .noted:
            return []
        }
        return [LoomFeatureRef(
            id: answer.id, domain: "attention", label: answer.label,
            conditionClause: answer.clause, outcomeClause: answer.clause,
            symbolName: "hand.raised", role: .outcomeOnly,
            sensitivity: .readerReported, provenance: .readerAuthored, rank: 83
        )]
    }
}

/// Which station the reader put on. Nobody plays the radio for them.
enum RadioProjector: LoomProjector {
    static let id = "radio"
    static let domains = ["radio"]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        slice.radioDays
            .filter { $0.dayIDs.contains(day.id) && !$0.title.isEmpty }
            .sorted { $0.stationID < $1.stationID }
            .map { station in
                LoomFeatureRef(
                    id: "radio:\(station.stationID)", domain: "radio", label: station.title,
                    conditionClause: "you were listening to \(station.title)",
                    outcomeClause: "you put \(station.title) on",
                    symbolName: "radio", role: .either,
                    provenance: .readerAuthored, rank: 64
                )
            }
    }
}

/// The rooms of the Book the reader went into on their own.
///
/// Only arrivals by hand are worn into the paper; a room the Book sent the
/// reader to leaves no mark, so this is never something the Book arranged.
/// The receiver has its own projector, and the shop, the index, the colophon
/// and the returned shelf say nothing about a day.
enum WanderProjector: LoomProjector {
    static let id = "wander"
    static let domains = ["wander"]

    static let skipped: Set<BookRoom> = [.bookshop, .pagesIndex, .colophon, .returned, .bookOfYou, .radio]

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.wear.rooms.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        return BookRoom.allCases.compactMap { room -> LoomFeatureRef? in
            guard !skipped.contains(room), slice.wear[room].days.contains(index) else { return nil }
            let place = room == .bookToday ? "the page with my mood on it" : room.plainName
            return LoomFeatureRef(
                id: "wander:\(room.rawValue)", domain: "wander", label: "trips into \(place)",
                conditionClause: "you went into \(place)",
                outcomeClause: "you went into \(place) by yourself",
                symbolName: "door.left.hand.open", role: .either,
                provenance: .readerAuthored, rank: 66
            )
        }
    }
}

/// The Inkbones: the reader throwing them, and the Curse throwing at the reader.
///
/// How a throw lands is chance, and chance cannot correlate with anything real,
/// so neither roll is a feature. Only the throwing is.
enum InkbonesProjector: LoomProjector {
    static let id = "inkbones"
    static let domains = ["inkbones", "curseThrow"]
    static let dayScope: LoomProjectorDayScope = .event

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.inkbones.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        let today = slice.inkbones.filter { GrimoireDay.index(for: $0.at, calendar: slice.calendar) == index }
        var out: [LoomFeatureRef] = []
        if today.contains(where: { $0.thrower == .reader }) {
            out.append(LoomFeatureRef(
                id: "inkbones:thrown", domain: "inkbones", label: "throwing the Inkbones",
                conditionClause: "you took up the Inkbones", outcomeClause: "you took up the Inkbones",
                symbolName: "dice", role: .either, provenance: .readerAuthored, rank: 70
            ))
        }
        if today.contains(where: { $0.thrower == .curse }) {
            out.append(LoomFeatureRef(
                id: "curse-throw:any", domain: "curseThrow", label: "days the Curse threw",
                conditionClause: "the Curse took a throw at you", outcomeClause: "the Curse took a throw at you",
                symbolName: "dice.fill", role: .conditionOnly, provenance: .systemEvent, rank: 30
            ))
        }
        return out
    }
}

/// The Curse greying a Page, and the reader taking it back.
///
/// The rescue answers the Curse's mark, so the day of a rescue is marked as
/// asked: taking a Page back proves the reader was paying attention, not that
/// any rule the Book holds about them was right.
enum GreyPageProjector: LoomProjector {
    static let id = "grey-pages"
    static let domains = ["greyPage", "greyRescue"]
    static let dayScope: LoomProjectorDayScope = .event

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        guard !slice.greyPages.isEmpty else { return [] }
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        var out: [LoomFeatureRef] = []
        if slice.greyPages.contains(where: { GrimoireDay.index(for: $0.markedAt, calendar: slice.calendar) == index }) {
            out.append(LoomFeatureRef(
                id: "grey-page:marked", domain: "greyPage", label: "Grey Pages",
                conditionClause: "the Curse put one of your Pages in the grey",
                outcomeClause: "the Curse put one of your Pages in the grey",
                symbolName: "cloud.fog", role: .conditionOnly, provenance: .systemEvent, rank: 30
            ))
        }
        if rescued(on: index, in: slice) {
            out.append(LoomFeatureRef(
                id: "grey-rescue:taken-back", domain: "greyRescue", label: "Pages you took back from the grey",
                conditionClause: "you took a Page back from the grey",
                outcomeClause: "you took a Page back from the grey",
                symbolName: "hand.raised.fill", role: .outcomeOnly, provenance: .readerAuthored, rank: 74
            ))
        }
        return out
    }

    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        rescued(on: GrimoireDay.index(for: day.date, calendar: slice.calendar), in: slice)
    }

    private static func rescued(on index: Int, in slice: GrimoireSlice) -> Bool {
        slice.greyPages.contains { threat in
            guard threat.status == .rescued, let at = threat.resolvedAt else { return false }
            return GrimoireDay.index(for: at, calendar: slice.calendar) == index
        }
    }
}

/// Electives the reader finished. A Cast member set each one, so these days are
/// marked as asked, the same as an errand paid.
enum ElectiveProjector: LoomProjector {
    static let id = "electives"
    static let domains = ["elective"]
    static let dayScope: LoomProjectorDayScope = .event

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        let done = finished(on: day, in: slice)
        guard !done.isEmpty else { return [] }
        var out = [LoomFeatureRef(
            id: "elective:any", domain: "elective", label: "electives",
            conditionClause: "you did one of your electives", outcomeClause: "you did one of your electives",
            symbolName: "graduationcap", role: .outcomeOnly, provenance: .readerAuthored, rank: 73
        )]
        var seen = Set<String>()
        for elective in done.sorted(by: { $0.characterID < $1.characterID })
        where seen.insert(elective.characterID).inserted && !elective.characterName.isEmpty {
            out.append(LoomFeatureRef(
                id: "elective:\(elective.characterID.lowercased())", domain: "elective",
                label: "electives for \(elective.characterName)",
                conditionClause: "you did an elective for \(elective.characterName)",
                outcomeClause: "you did an elective for \(elective.characterName)",
                symbolName: "graduationcap", role: .outcomeOnly, provenance: .readerAuthored, rank: 73
            ))
        }
        return out
    }

    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool {
        !finished(on: day, in: slice).isEmpty
    }

    private static func finished(on day: BookDay, in slice: GrimoireSlice) -> [UnwrittenElective] {
        let index = GrimoireDay.index(for: day.date, calendar: slice.calendar)
        return slice.electives.filter { elective in
            guard let at = elective.completedAt, elective.releasedAt == nil else { return false }
            return GrimoireDay.index(for: at, calendar: slice.calendar) == index
        }
    }
}

/// The days the reader put a new place on the map.
enum PlaceMakingProjector: LoomProjector {
    static let id = "place-making"
    static let domains = ["placeMaking"]
    static let dayScope: LoomProjectorDayScope = .event

    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] {
        // Anchors carry their founding as a plain "yyyy-MM-dd", the same id a
        // BookDay has, so no date parsing is needed at all.
        guard slice.namedPlaces.contains(where: { $0.created == day.id }) else { return [] }
        return [LoomFeatureRef(
            id: "place-made:new", domain: "placeMaking", label: "new places on the map",
            conditionClause: "you put a new place on the map", outcomeClause: "you put a new place on the map",
            symbolName: "mappin.and.ellipse", role: .outcomeOnly, provenance: .readerAuthored, rank: 72
        )]
    }
}
