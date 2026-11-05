import XCTest
@testable import InsideCoverCore

/// Every bet the Book makes is built from three bits of each feature: a label
/// ("rainy days"), a condition clause ("it was raining") and an outcome clause
/// ("the rain came"). They used to be filing words dropped into sentences —
/// "when the almanac had a author on it, your medium leaned words" — so these
/// checks run the real projectors across as many inputs as they can reach and
/// read every piece the way a reader would meet it.
final class GrimoireBetWordingTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func dayID(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// Every feature the projectors can be pushed into producing.
    private func everyFeature() -> [LoomFeatureRef] {
        var out: [LoomFeatureRef] = []
        let base = date(2026, 10, 14)

        // The world around a Page: each hour, a spread of weather words, places.
        for (hour, kinds) in [(8, ["cafe", "nationalPark"]), (15, ["fitnessCenter"]), (19, ["beach"]), (23, ["airport"])] {
            for kind in kinds {
                var context = BookPageContextSnapshot(
                    at: date(2026, 10, 14, hour: hour), calendar: calendar,
                    weatherTags: ["rain", "clear", "fog", "fogbow", "overcast"],
                    nearbyAnchorID: "user-anchor-the-quiet-end-1a2b3c4d"
                )
                context.placeKind = kind
                out += WorldConditionsProjector.features(for: context)
            }
        }

        // The reader's own Pages, with every sensory value the app really writes.
        var page = BookPage(
            id: "p", type: .diary, createdAt: base, promptText: "p",
            userInput: String(repeating: "lantern harbour kettle ", count: 40),
            tags: [
                "sender:pippa", "entity:wicker-eddies", "choice:sliceoflife",
                "genre:cozy-mystery", "genre:kindly-ghost", "form:small-mystery"
            ],
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: base, calendar: calendar, bodyScore: 20, sleepHours: 4.5)
        )
        page.mediaAssets = [
            BookPageMediaAsset(id: "photo", kind: .photoLibraryAsset, reference: "asset://p"),
            BookPageMediaAsset(id: "voice", kind: .audioFile, reference: "/tmp/v.m4a")
        ]
        let observations: [(SensoryObservation.Dimension, String)] = [
            (.modality, "words"), (.modality, "photo"), (.modality, "voice"),
            (.subject, "gull"), (.palette, "warm"), (.palette, "muted"),
            (.brightness, "soft light"), (.brightness, "low light"),
            (.composition, "landscape, people-0"), (.composition, "portrait, people-2"),
            (.voiceCadence, "short bursts"), (.voiceCadence, "long-paused phrases"),
            (.voiceEnergy, "hushed"), (.voiceEnergy, "high contrast")
        ]
        page.sensoryFolio = SensoryFolio(
            schemaVersion: SensoryFolio.currentSchemaVersion,
            observations: observations.map {
                SensoryObservation(dimension: $0.0, value: $0.1, confidence: 1, extractorID: "test")
            },
            vectors: []
        )
        let slice = GrimoireSlice(days: [], calendar: calendar)
        for projector: any LoomProjector.Type in [KeptPageProjector.self, ReaderWordsProjector.self,
                                                  StoryTagProjector.self, SensoryProjector.self] {
            out += projector.features(forPage: page, in: slice)
        }
        for (body, sleep) in [(20, 4.5), (50, 7.0), (90, 9.5)] {
            var inner = page
            inner.context = BookPageContextSnapshot(at: base, calendar: calendar, bodyScore: body, sleepHours: sleep)
            out += InnerWeatherProjector.features(forPage: inner, in: slice)
        }

        // Compass runs: every mode and every place.
        for mode in WonderConciergeMode.allCases {
            for place in CompassPlaceContext.allCases {
                let run = BookPage(
                    id: "run", type: .wonderCompass, createdAt: base, promptText: "p", userInput: "u",
                    tags: ["concierge:\(mode.rawValue)", "compass-place:\(place.rawValue)"],
                    origin: .userAuthored
                )
                out += CompassRunProjector.features(forPage: run, in: slice)
            }
        }

        // The raw day: each band of light, travel and calendar.
        for (minutes, events, travelled) in [(8 * 60, 0, true), (11 * 60, 2, false), (14 * 60, 6, true)] {
            var entry = DaybookEntry(dayID: dayID(base), date: base, fidelity: .live)
            entry.weatherTags = ["snow", "cold"]
            entry.placeLabel = "West Harbor"
            entry.daylightMinutes = minutes
            entry.calendarEventCount = events
            entry.travelled = travelled
            out += DaybookProjector.features(forDaybook: entry, in: slice)
            out += DayShapeProjector.features(forDaybook: entry, in: slice)
        }
        out += ReaderStateProjector.features(aliveness: 9, wonder: 9, hiddenMagic: 9)

        // A whole year of almanac days and moons, so every kind the almanac
        // keeps has a chance to speak.
        for offset in 0..<366 {
            let day = calendar.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            let bookDay = BookDay(id: dayID(day), date: day, pages: [])
            out += AlmanacProjector.features(forDay: bookDay, in: slice)
            out += MoonProjector.features(forDay: bookDay, in: slice)
        }

        // Workings from every recipe, set and ended the same day.
        for (recipe, kind, id, name) in [
            ("book-stolen-opening", BookWorkingInitiatorKind.book, "the-book", "The Book"),
            ("wicker-case-against-routine", .character, "wicker-eddies", "Wicker Eddies"),
            ("serenity-small-detour", .character, "serenity-brown", "Serenity Brown"),
            ("trencher-table-kept-open", .character, "ambrose-trencher", "Ambrose Trencher")
        ] {
            for status in [BookWorkingStatus.returned, .elapsed, .cancelled] {
                let working = BookWorking(
                    id: "w-\(recipe)", recipeID: recipe,
                    initiatorKind: kind, initiatorID: id, initiatorName: name,
                    title: "T", summons: "s", invitation: "i", returnPrompt: "r",
                    createdAt: base, startsAt: base, endsAt: base,
                    status: status, effects: [], returnedAt: base
                )
                var workingSlice = slice
                workingSlice.workings = [working]
                out += WorkingProjector.features(forDay: BookDay(id: dayID(base), date: base, pages: []), in: workingSlice)
            }
        }
        return out
    }

    private func pieces(of feature: LoomFeatureRef) -> [String] {
        [feature.label, feature.conditionClause, feature.outcomeClause]
    }

    // MARK: The checks

    func testTheFixtureReachesEveryKindOfBet() {
        let domains = Set(everyFeature().map(\.domain))
        for domain in ["hour", "weather", "place", "placeKind", "pageKind", "media", "ink", "word",
                       "cast", "choice", "genre", "storyForm", "body", "sleep", "modality", "subject",
                       "visualPalette", "visualBrightness", "visualComposition", "voiceCadence",
                       "voiceEnergy", "compass", "compassPlace", "daylight", "travel", "calendarLoad",
                       "readerState", "weekPart", "season", "writing", "almanac", "moon",
                       "working", "workingInitiator", "workingEpisode", "workingOutcome"] {
            XCTAssertTrue(domains.contains(domain), "nothing reached \(domain)")
        }
    }

    /// "a author", "a occupied calendar".
    func testNoArticleTripsOverItsNoun() {
        for feature in everyFeature() {
            for piece in pieces(of: feature) {
                let words = piece.lowercased().split(separator: " ").map(String.init)
                for (word, next) in zip(words, words.dropFirst()) where word == "a" {
                    XCTAssertFalse("aeiou".contains(next.first ?? "x"), "“a \(next)” in: \(piece)")
                }
            }
        }
    }

    /// No filing word reaches the page: no camel-case ("inWorld", "closeToHome"),
    /// no underscores or colons, no ids.
    func testNoSlugReachesTheReader() {
        for feature in everyFeature() {
            for piece in pieces(of: feature) {
                XCTAssertNil(piece.range(of: "[a-z][A-Z]", options: .regularExpression), "camel-case in: \(piece)")
                XCTAssertFalse(piece.contains("_") || piece.contains(":"), "a slug in: \(piece)")
                XCTAssertFalse(piece.contains("anchor-"), "an Anchor id in: \(piece)")
                XCTAssertFalse(piece.contains("sliceoflife"), "a squashed choice in: \(piece)")
            }
        }
    }

    /// An Anchor id carries the reader's own name for the place inside it.
    func testAnAnchorIsCalledWhatTheReaderCalledIt() {
        let place = everyFeature().first { $0.domain == "place" }
        XCTAssertEqual(place?.conditionClause, "you were at the quiet end")
    }

    /// The Book is the narrator. It never calls itself "the Book".
    func testTheBookNeverNamesItself() {
        for feature in everyFeature() {
            for piece in pieces(of: feature) {
                XCTAssertFalse(piece.lowercased().contains("the book"), "the Book named itself: \(piece)")
            }
        }
    }

    /// The old clauses that read like a meter, not a child.
    func testNoMeterReadings() {
        let meter = [" leaned ", "reading high", "reading low", "body signal", "ran thin", "ran full",
                     "light ran", "the Page carried", "you had ", "was about", "came at ",
                     "fell on", "ran its course", "the path taken", "wore the shape"]
        for feature in everyFeature() {
            for piece in pieces(of: feature) {
                for phrase in meter {
                    XCTAssertFalse(piece.contains(phrase), "“\(phrase.trimmingCharacters(in: .whitespaces))” in: \(piece)")
                }
            }
        }
    }

    /// A clause has to stand as a sentence after "When". Each one carries a verb
    /// a child would use, and starts in lower case unless it starts with a name.
    func testEveryClauseIsASentence() {
        let verbs = [" was", " were", " came", " went", " took", " kept", " used", " told", " picked",
                     " slept", " stayed", " talked", " set", " had", " spotted", " travelled",
                     " wrote", " didn't", " did", " let", " put", " happened", " made", " was"]
        for feature in everyFeature() {
            for clause in [feature.conditionClause, feature.outcomeClause] {
                XCTAssertTrue(verbs.contains { " \(clause)".contains($0) }, "no verb in: \(clause)")
                XCTAssertFalse(clause.hasSuffix("."), "a clause carries its own full stop: \(clause)")
                XCTAssertFalse(clause.contains("  "), "a double space in: \(clause)")
            }
        }
    }

    /// The almanac kinds are the Book's own filing words. Each one has to come
    /// out as what the day actually was.
    func testEveryAlmanacDaySaysWhatTheDayWas() {
        let almanac = everyFeature().filter { $0.domain == "almanac" }
        XCTAssertFalse(almanac.isEmpty)
        for feature in almanac {
            XCTAssertFalse(feature.conditionClause.contains("almanac"), feature.conditionClause)
        }
        let author = almanac.first { $0.id == "almanac:author" }
        XCTAssertEqual(author?.label, "writers' birthdays")
        XCTAssertEqual(author?.conditionClause, "it was a famous writer's birthday")
    }

    /// The bet the reader saw on Rabbit, said again: it has to read as two plain
    /// facts and a count.
    func testTheWritersBirthdayBetReadsPlainly() throws {
        var ledger = GrimoireLedger()
        let author = try XCTUnwrap(everyFeature().first { $0.id == "almanac:author" })
        let words = try XCTUnwrap(everyFeature().first { $0.id == "modality:words" })
        var observations: [LoomObservation] = []
        for day in 0..<120 {
            var features: [LoomFeatureRef] = []
            if day % 9 == 0 { features.append(author) }
            if day % 9 == 0 || day % 2 == 0 { features.append(words) }
            observations.append(LoomObservation(
                id: "d\(day)", day: day, occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "p\(day)", evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        for _ in 0..<40 {
            if ledger.sweep(now: GrimoireDay.date(for: 121, calendar: calendar), budget: 900, calendar: calendar).finished { break }
        }
        let row = try XCTUnwrap(ledger.rows.values.first {
            $0.shape == .conditional && $0.conditionID == "almanac:author" && $0.outcomeID == "modality:words"
        })
        let stats = try XCTUnwrap(ledger.currentStats(for: row, calendar: calendar))
        let claim = GrimoireVoice.plainClaim(row: row, stats: stats, ledger: ledger, calendar: calendar)
        XCTAssertEqual(claim, "When it was a famous writer's birthday, your Page was written in words.")
        let evidence = GrimoireVoice.evidence(row: row, stats: stats, ledger: ledger, calendar: calendar)
        XCTAssertTrue(evidence.hasPrefix("I counted. It happened on \(stats.inHits) of those \(stats.inCount) days"), evidence)
        let promise = GrimoireVoice.promise(row: row, stats: stats, ledger: ledger)
        XCTAssertTrue(promise.contains("days like that"), promise)
        XCTAssertFalse(promise.contains("turns of"), promise)
    }

    /// A bet already made keeps its number but says it in today's words.
    func testAnOldBetIsSaidInTodaysWords() throws {
        var ledger = GrimoireLedger()
        let rain = try XCTUnwrap(everyFeature().first { $0.id == "weather:snow" })
        let photo = try XCTUnwrap(everyFeature().first { $0.id == "word:lantern" })
        var observations: [LoomObservation] = []
        for day in 0..<120 {
            var features: [LoomFeatureRef] = []
            if day % 5 == 0 { features += [rain, photo] }
            if day % 7 == 0 { features.append(photo) }
            observations.append(LoomObservation(
                id: "d\(day)", day: day, occurredAt: GrimoireDay.date(for: day, calendar: calendar),
                features: features, evidencePageID: "p\(day)", evidenceLine: ""
            ))
        }
        ledger.ingest(observations)
        for _ in 0..<40 {
            if ledger.sweep(now: GrimoireDay.date(for: 121, calendar: calendar), budget: 900, calendar: calendar).finished { break }
        }
        var row = try XCTUnwrap(ledger.rows.values.first { $0.conditionID == "weather:snow" && $0.outcomeID == "word:lantern" })
        row.falsifier = GrimoireFalsifier(
            committedAt: Date(), baselineInCount: 10, baselineInHits: 8, floorRate: 0.4,
            opportunitiesRequired: 4, line: "Watch it with me. 4 more turns of rain. If it stops, the ink sinks back into the paper and this goes."
        )
        let promise = try XCTUnwrap(GrimoireVoice.currentPromise(row: row, ledger: ledger))
        XCTAssertFalse(promise.contains("turns of"), promise)
        XCTAssertTrue(promise.lowercased().contains("four"), "the committed number has to survive: \(promise)")
    }
}
