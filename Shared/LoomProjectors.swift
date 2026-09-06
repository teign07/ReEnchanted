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
}

extension LoomProjector {
    static var dayScope: LoomProjectorDayScope { .wholeDay }
    static func features(forPage page: BookPage, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func features(forDay day: BookDay, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func bookAsked(forDay day: BookDay, in slice: GrimoireSlice) -> Bool { false }
    static func features(forDaybook entry: DaybookEntry, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
    static func features(forPulse pulse: ReaderStatePulseRecord, in slice: GrimoireSlice) -> [LoomFeatureRef] { [] }
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
        WorldEventProjector.self
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
                    outcomeClause: "those circumstances arrived together",
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
        return out
    }
}

// MARK: - Small shared shapes

private func humanised(_ token: String) -> String {
    token.replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .trimmingCharacters(in: .whitespaces)
}

/// Weather tags arrive as bare nouns and bare adjectives in the same list —
/// "rain" beside "clear" — and both were being dropped into "it was ___".
/// "It was clear" is a sentence. "It was rain" is not, and the reader meets
/// these clauses in the middle of a claim the Book is asking them to check.
private func weatherClauses(_ tag: String) -> (condition: String, outcome: String) {
    let word = humanised(tag).lowercased()
    let known: [String: (String, String)] = [
        "rain": ("it was raining", "rain came"),
        "drizzle": ("it was drizzling", "drizzle came"),
        "shower": ("it was showering", "showers came"),
        "showers": ("it was showering", "showers came"),
        "snow": ("it was snowing", "snow came"),
        "sleet": ("it was sleeting", "sleet came"),
        "hail": ("it was hailing", "hail came"),
        "fog": ("it was foggy", "fog came"),
        "mist": ("it was misty", "mist came"),
        "haze": ("it was hazy", "haze came"),
        "wind": ("it was windy", "wind came"),
        "storm": ("there was a storm", "a storm came"),
        "thunderstorm": ("there was a thunderstorm", "a thunderstorm came"),
        "thunder": ("there was thunder", "thunder came"),
        "cloud": ("it was cloudy", "clouds came"),
        "clouds": ("it was cloudy", "clouds came"),
        "sun": ("it was sunny", "the sun came out"),
        "sunshine": ("it was sunny", "the sun came out"),
        "ice": ("it was icy", "ice came"),
        "frost": ("it was frosty", "frost came")
    ]
    if let found = known[word] { return found }
    // Anything that already reads as a description of the day is left alone:
    // clear, overcast, cold, warm, humid, breezy, freezing, grey.
    let looksLikeADescription = word.hasSuffix("y") || word.hasSuffix("ing")
        || word.hasSuffix("ed") || word.hasSuffix("cast") || word.hasSuffix("m")
        || ["clear", "cold", "hot", "damp", "dry", "grey", "gray", "fair", "mild",
            "crisp", "bright", "dark", "wet", "cool"].contains(word)
    if looksLikeADescription { return ("it was \(word)", "the sky was \(word)") }
    // An unrecognised noun. "There was fogbow" is odd but it is a sentence,
    // which is more than the old line managed.
    return ("there was \(word)", "\(word) came")
}

private func band(_ value: Int, low: Int, high: Int) -> String {
    if value <= low { return "low" }
    if value >= high { return "high" }
    return "middling"
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
            out.append(LoomFeatureRef(
                id: "hour:\(part)", domain: "hour", label: part,
                conditionClause: "it was \(part)", outcomeClause: "you came at \(part)",
                symbolName: "clock", role: .conditionOnly, rank: 15
            ))
        }
        for tag in context.weatherTags.prefix(3) {
            out.append(LoomFeatureRef(
                id: "weather:\(tag)", domain: "weather", label: humanised(tag),
                conditionClause: weatherClauses(tag).condition,
                outcomeClause: weatherClauses(tag).outcome,
                symbolName: "cloud", role: .conditionOnly, rank: 10
            ))
        }
        let placeLabel = context.locationLabel?.nonEmpty ?? context.nearbyAnchorID?.nonEmpty
        if let place = placeLabel {
            out.append(LoomFeatureRef(
                id: "place:\(place.lowercased())", domain: "place", label: humanised(place),
                conditionClause: "you were at \(humanised(place))",
                outcomeClause: "you went to \(humanised(place))",
                symbolName: "mappin", role: .either, rank: 25
            ))
        }
        // What *kind* of place it was, which is the half the Book could never
        // reach before: a place feature keyed on an Anchor id says "you write
        // differently at anchor-7f3a", and only a taxonomy can say "you write
        // differently near water".
        if let kind = context.placeKind?.nonEmpty {
            out.append(LoomFeatureRef(
                id: "place-kind:\(kind)", domain: "placeKind", label: humanised(kind),
                conditionClause: "you were somewhere that is a \(humanised(kind))",
                outcomeClause: "you went to a \(humanised(kind))",
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
            id: "week:\(part)", domain: "weekPart", label: part,
            conditionClause: "it was \(part)", outcomeClause: "it fell on \(part)",
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
            domain: "writing", label: wrote ? "wrote something" : "wrote nothing",
            conditionClause: wrote ? "you had written" : "you had written nothing",
            outcomeClause: wrote ? "you wrote something" : "you wrote nothing",
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
                id: "kept:\(page.type.rawValue)", domain: "pageKind", label: page.type.shortTitle,
                conditionClause: "a \(page.type.shortTitle) Page was in your hands",
                outcomeClause: "you kept a \(page.type.shortTitle) Page",
                symbolName: page.type.symbolName, role: .outcomeOnly,
                provenance: .readerAuthored, rank: 70
            )
        ]
        if page.hasReaderPhotograph {
            out.append(LoomFeatureRef(
                id: "media:photograph", domain: "media", label: "a photograph",
                conditionClause: "you had taken a photograph",
                outcomeClause: "you kept a photograph",
                symbolName: "camera", role: .either, provenance: .readerAuthored, rank: 72
            ))
        }
        if page.hasReaderAudioRecording {
            out.append(LoomFeatureRef(
                id: "media:voice", domain: "media", label: "your voice",
                conditionClause: "you had spoken into the Book",
                outcomeClause: "you spoke into the Book",
                symbolName: "waveform", role: .either, provenance: .readerAuthored, rank: 72
            ))
        }
        if let text = page.readerAuthoredTextForAnalysis {
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
            let weight = words >= 90 ? "heavy" : (words >= 30 ? "steady" : "light")
            out.append(LoomFeatureRef(
                id: "ink:\(weight)", domain: "ink", label: "\(weight) ink",
                conditionClause: "the ink had run \(weight)",
                outcomeClause: "the ink ran \(weight)",
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
        "our", "out", "one",
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
            seen.insert(word)
            out.append(LoomFeatureRef(
                id: "word:\(word)", domain: "word", label: "“\(word)”",
                conditionClause: "you had used the word \(word)",
                outcomeClause: "you used the word \(word)",
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
            if let token = value(after: "sender:") ?? value(after: "entity:") {
                let name = humanised(token)
                return LoomFeatureRef(
                    id: "cast:\(token)", domain: "cast", label: name,
                    conditionClause: "\(name) was about",
                    outcomeClause: "\(name) came to you",
                    symbolName: "person.crop.rectangle.stack",
                    role: .either, provenance: .systemEvent, rank: 60
                )
            }
            if let token = value(after: "choice:") {
                let name = humanised(token)
                return LoomFeatureRef(
                    id: "choice:\(token)", domain: "choice", label: name,
                    conditionClause: "\(name) was the path taken",
                    outcomeClause: "you chose \(name)",
                    symbolName: "arrow.triangle.branch",
                    role: .either, provenance: .systemEvent, rank: 75
                )
            }
            if let token = value(after: "genre:") {
                let name = humanised(token)
                return LoomFeatureRef(
                    id: "genre:\(token)", domain: "genre", label: name,
                    conditionClause: "the story wore the shape of \(name)",
                    outcomeClause: "you took a \(name) story",
                    symbolName: "books.vertical",
                    role: .either, provenance: .systemEvent, rank: 75
                )
            }
            if let token = value(after: "form:") {
                let name = humanised(token)
                return LoomFeatureRef(
                    id: "story-form:\(token)", domain: "storyForm", label: name,
                    conditionClause: "the story took the form \(name)",
                    outcomeClause: "you took a story shaped like \(name)",
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
            let level = band(score, low: 33, high: 67)
            out.append(LoomFeatureRef(
                id: "body:\(level)", domain: "body", label: "\(level) body signal",
                conditionClause: "your body was reading \(level)",
                outcomeClause: "your body read \(level)",
                symbolName: "heart", role: .conditionOnly,
                sensitivity: .innerState, rank: 30
            ))
        }
        if let hours = context.sleepHours {
            let level = hours < 6 ? "short" : (hours > 8 ? "long" : "ordinary")
            out.append(LoomFeatureRef(
                id: "sleep:\(level)", domain: "sleep", label: "\(level) sleep",
                conditionClause: "the night before had been \(level)",
                outcomeClause: "you slept \(level)",
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
                conditionClause: "\(name) was about", outcomeClause: "\(name) came to you",
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
                    conditionClause: "\(kind.name) was about",
                    outcomeClause: "\(kind.name) came to you",
                    symbolName: "sparkles", role: .either,
                    provenance: .systemEvent, rank: 58
                ))
            }
            if let deliveredAt = bargain.deliveredAt,
               GrimoireDay.index(for: deliveredAt, calendar: slice.calendar) == index,
               seen.insert("kept:\(kind.rawValue)").inserted {
                out.append(LoomFeatureRef(
                    id: "fae-kept:\(kind.rawValue)", domain: "faeKept",
                    label: "a bargain with \(kind.name)",
                    conditionClause: "you had kept a bargain with \(kind.name)",
                    outcomeClause: "you kept your side with \(kind.name)",
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
            return LoomFeatureRef(
                id: "working-by:\(working.initiatorID)", domain: "workingInitiator", label: name,
                conditionClause: "\(name) had set you something",
                outcomeClause: "\(name) set you something",
                symbolName: "person.wave.2", role: .conditionOnly,
                provenance: .systemEvent, rank: 59
            )
        }

        for working in slice.workings {
            let recipe = humanised(working.recipeID)

            if GrimoireDay.index(for: working.createdAt, calendar: slice.calendar) == index {
                if seen.insert("set:\(working.recipeID)").inserted {
                    out.append(LoomFeatureRef(
                        id: "working:\(working.recipeID)", domain: "working", label: recipe,
                        conditionClause: "a \(recipe) was set",
                        outcomeClause: "you took on a \(recipe)",
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
                    ($0, "returned", "coming back from it", "you came back from it", true)
                }
            case .elapsed:
                ending = (working.endsAt, "lapsed", "letting it lapse", "you let it lapse", false)
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
                    label: recipe,
                    conditionClause: "the working that ended was a \(recipe)",
                    outcomeClause: "a \(recipe) ran its course",
                    symbolName: "wand.and.stars", role: .either,
                    provenance: .systemEvent, rank: 61
                ))
            }
            if let by = initiator(working) { out.append(by) }
            if seen.insert("outcome:\(ending.id)").inserted {
                out.append(LoomFeatureRef(
                    id: "working-outcome:\(ending.id)", domain: "workingOutcome",
                    label: ending.label,
                    conditionClause: "you had finished by \(ending.label)",
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
                let name = mode?.title ?? humanised(token)
                return LoomFeatureRef(
                    id: "compass:\(stable)", domain: "compass", label: name,
                    conditionClause: "you had been out on a \(name) run",
                    outcomeClause: "you went out on a \(name) run",
                    symbolName: "location.north.circle", role: .either,
                    provenance: .readerAuthored, rank: 40
                )
            }
            if tag.hasPrefix("compass-place:"), let token = String(tag.dropFirst(14)).nonEmpty {
                let place = CompassPlaceContext.allCases.first { $0.rawValue.lowercased() == token }
                let stable = place?.rawValue ?? token
                let name = place?.title.lowercased() ?? humanised(token)
                return LoomFeatureRef(
                    id: "compass-place:\(stable)", domain: "compassPlace", label: name,
                    conditionClause: "the Compass run stayed \(name)",
                    outcomeClause: "you took the Compass \(name)",
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
            out.append(LoomFeatureRef(
                id: "weather:\(tag)", domain: "weather", label: humanised(tag),
                conditionClause: weatherClauses(tag).condition,
                outcomeClause: weatherClauses(tag).outcome,
                symbolName: "cloud", role: .conditionOnly, rank: 10
            ))
        }
        if let place = entry.placeLabel?.nonEmpty ?? entry.nearbyAnchorID?.nonEmpty {
            out.append(LoomFeatureRef(
                id: "place:\(place.lowercased())", domain: "place", label: humanised(place),
                conditionClause: "you were at \(humanised(place))", outcomeClause: "you went to \(humanised(place))",
                symbolName: "mappin", role: .either, rank: 25
            ))
            if isWaterPlace(place) { out.append(waterFeature()) }
        }
        if let minutes = entry.daylightMinutes {
            // How much light the day actually had. Banded, because the Book is
            // asking whether the dark half of the year changes the reader, not
            // counting minutes at them.
            let band = minutes >= 13 * 60 ? "long" : (minutes <= 9 * 60 ? "short" : "even")
            out.append(LoomFeatureRef(
                id: "daylight:\(band)", domain: "daylight", label: "\(band) light",
                conditionClause: "the day had \(band) light",
                outcomeClause: "the light ran \(band)",
                symbolName: "sun.horizon", role: .conditionOnly, rank: 12
            ))
        }
        if let travelled = entry.travelled {
            out.append(LoomFeatureRef(
                id: travelled ? "travel:moved" : "travel:stayed",
                domain: "travel", label: travelled ? "a travelled day" : "a stayed-put day",
                conditionClause: travelled ? "you had travelled" : "you had stayed close",
                outcomeClause: travelled ? "you travelled" : "you stayed close",
                symbolName: "figure.walk", role: .either, rank: 32
            ))
        }
        if let events = entry.calendarEventCount {
            let load = events == 0 ? "open" : (events >= 4 ? "crowded" : "occupied")
            out.append(LoomFeatureRef(
                id: "calendar-load:\(load)", domain: "calendarLoad", label: "a \(load) calendar",
                conditionClause: "the calendar was \(load)", outcomeClause: "the calendar was \(load)",
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
                conditionClause: "you had reported feeling more alive",
                outcomeClause: "you said you felt more alive",
                symbolName: "sparkles", role: .outcomeOnly,
                sensitivity: .readerReported, provenance: .readerAuthored, rank: 82
            ))
            out.append(brightMomentFeature())
        }
        if let wonder, wonder >= 7 {
            out.append(LoomFeatureRef(
                id: "reader-state:wonder", domain: "readerState", label: "a strong wonder report",
                conditionClause: "you had reported strong wonder",
                outcomeClause: "you reported strong wonder",
                symbolName: "eyes", role: .outcomeOnly,
                sensitivity: .readerReported, provenance: .readerAuthored, rank: 82
            ))
            out.append(brightMomentFeature())
        }
        if let hiddenMagic, hiddenMagic >= 7 {
            out.append(LoomFeatureRef(
                id: "reader-state:hidden-magic", domain: "readerState", label: "magic feeling close",
                conditionClause: "you had said magic felt close",
                outcomeClause: "you said magic felt close",
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
            id: "reader-state:bright-moment", domain: "readerState", label: "a bright moment",
            conditionClause: "you had called the moment bright",
            outcomeClause: "you reported a bright moment",
            symbolName: "sun.max", role: .outcomeOnly,
            sensitivity: .readerReported, provenance: .readerAuthored, rank: 84
        )
    }
}

private func waterFeature() -> LoomFeatureRef {
    LoomFeatureRef(
        id: "place-kind:water", domain: "placeKind", label: "water nearby",
        conditionClause: "water was nearby", outcomeClause: "you went near water",
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
        for (dimension, domain, prefix, symbol) in lanes {
            for value in folio.values(for: dimension) {
                let token = value.lowercased()
                    .replacingOccurrences(of: " ", with: "-")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                guard !token.isEmpty else { continue }
                let readable = humanised(token).lowercased()
                out.append(LoomFeatureRef(
                    id: "\(domain):\(token)", domain: domain,
                    label: "\(prefix) \(readable)",
                    conditionClause: "the Page carried \(readable) \(prefix.lowercased())",
                    outcomeClause: "your \(prefix.lowercased()) leaned \(readable)",
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
            let token = signal.id.lowercased().replacingOccurrences(of: " ", with: "-")
            guard !token.isEmpty else { return nil }
            return LoomFeatureRef(
                id: "meaning:\(token)", domain: "meaning", label: signal.subjectName,
                conditionClause: "the thread called \(signal.subjectName) was in the margin",
                outcomeClause: "your Pages returned to \(signal.subjectName)",
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
        return [LoomFeatureRef(
            id: "moon:\(band)", domain: "moon", label: "a \(band) moon",
            conditionClause: "the moon was \(band)",
            outcomeClause: "the moon ran \(band)",
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
                    ($0, "paid", "paying an errand", "you paid what a talisman asked", true)
                }
            case .lapsed:
                ending = (errand.deadline, "lapsed", "letting an errand lapse", "you let a talisman's ask lapse", false)
            case .owed:
                ending = nil
            }
            guard let ending,
                  GrimoireDay.index(for: ending.day, calendar: slice.calendar) == index else { continue }

            let talisman = humanised(errand.talismanID)
            if seen.insert("by:\(errand.talismanID)").inserted {
                out.append(LoomFeatureRef(
                    id: "talisman:\(errand.talismanID)", domain: "talisman", label: talisman,
                    conditionClause: "\(talisman) had asked you for something",
                    outcomeClause: "\(talisman) asked you for something",
                    symbolName: "seal", role: .conditionOnly,
                    provenance: .systemEvent, rank: 57
                ))
            }
            if seen.insert("outcome:\(ending.id)").inserted {
                out.append(LoomFeatureRef(
                    id: "errand-outcome:\(ending.id)", domain: "errandOutcome", label: ending.label,
                    conditionClause: "you had finished by \(ending.label)",
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
                id: "aside:answered", domain: "asideReply", label: "answering me",
                conditionClause: "you had answered me",
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
            id: "pocket:kept", domain: "pocket", label: "something for the Pocket",
            conditionClause: "you had put something in my Pocket",
            outcomeClause: "you pressed something into my Pocket",
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
                    conditionClause: "you had been inside \(jump.title)",
                    outcomeClause: "you went into \(jump.title)",
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
                        ? "you had come back carrying something"
                        : "you had come back empty-handed",
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
            let name = humanised(tradition.title)
            out.append(LoomFeatureRef(
                id: "observance:\(tradition.kind.rawValue)", domain: "observance", label: name,
                conditionClause: "you had kept \(name)",
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
        return [LoomFeatureRef(
            id: "almanac:\(kind)", domain: "almanac", label: humanised(kind),
            conditionClause: "the almanac had a \(humanised(kind)) on it",
            outcomeClause: "the day was a \(humanised(kind))",
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
            if seen.insert("phase:\(phase)").inserted {
                out.append(LoomFeatureRef(
                    id: "world-event-phase:\(phase)", domain: "worldEventPhase",
                    label: "a world event \(humanised(phase))",
                    conditionClause: "the world was \(humanised(phase))",
                    outcomeClause: "the world was \(humanised(phase))",
                    symbolName: "clock.arrow.circlepath", role: .conditionOnly,
                    provenance: .systemEvent, rank: 23
                ))
            }
        }
        return out
    }
}
