import XCTest
@testable import InsideCoverCore

/// The Context Weave — the general relationship finder. It may only claim a
/// connection between how the reader writes and the world the pages were kept
/// in when both sides of the comparison exist, the evidence spans real days,
/// and the context was recorded at keep time rather than guessed later.
final class ContextWeaveTests: XCTestCase {

    // A Monday, so daysAgo arithmetic lands on predictable weekdays.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12))!

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func page(
        _ text: String,
        at date: Date,
        id: String = UUID().uuidString,
        weather: [String]? = nil,
        bodyScore: Int? = nil,
        events: Int? = nil
    ) -> BookPage {
        var context: BookPageContextSnapshot?
        if weather != nil || bodyScore != nil || events != nil {
            context = BookPageContextSnapshot(
                at: date,
                weatherTags: weather ?? [],
                bodyScore: bodyScore,
                calendarEventCount: events
            )
        }
        return BookPage(
            id: id,
            type: .diary,
            createdAt: date,
            promptText: "Prompt",
            userInput: text,
            origin: .userAuthored,
            context: context
        )
    }

    /// A BookDay whose id matches its pages' calendar day — `capturedPages`
    /// windows on the parsed id, so a mislabeled day hides its pages.
    private func day(pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? now
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func days(from pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages) { BookDay.id(for: $0.createdAt) }
            .values
            .map { day(pages: $0.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.id < $1.id }
    }

    private let heavyLine = "The kitchen felt lonely tonight and the tea went cold while I sat tired."
    private let plainLine = "The counter held three oranges and the window showed the neighbor's ladder."

    /// Five rainy heavy pages across five days against eight plain bright-sky
    /// pages — the canonical "sadder sentences on rain days" archive.
    private func rainArchive(dryWeather: [String]? = ["bright"]) -> [BookDay] {
        let rainy = (0..<5).map { index in
            page(heavyLine, at: daysAgo(2 + index * 2), id: "rain-\(index)", weather: ["rain"])
        }
        let dry = (0..<8).map { index in
            page(plainLine, at: daysAgo(3 + index * 2), id: "dry-\(index)", weather: dryWeather)
        }
        return days(from: rainy + dry)
    }

    // MARK: - Tone

    func testToneReadsBrightAndHeavyInk() {
        XCTAssertEqual(ContextWeave.tone(of: "We laughed until the grateful kettle joined in."), .bright)
        XCTAssertEqual(ContextWeave.tone(of: heavyLine), .heavy)
        XCTAssertNil(ContextWeave.tone(of: plainLine), "Neutral prose carries no tone verdict.")
        XCTAssertNil(ContextWeave.tone(of: "A happy morning, then a lonely evening."), "Ties are never broken on the reader's behalf.")
    }

    func testToneLexiconsExcludeWeatherAndHourWords() {
        // If "bright" or "dark" counted as tone, a clear sky or a late hour
        // could predict its own connection and the reading would be circular.
        let forbidden = ["rain", "rainy", "storm", "snow", "fog", "wind", "cloud",
                         "bright", "sun", "sunny", "hot", "cold", "warm", "grey",
                         "gray", "dark", "night", "morning"]
        for word in forbidden {
            XCTAssertFalse(ContextWeave.brightInkWords.contains(word), "\(word) must not read as bright ink")
            XCTAssertFalse(ContextWeave.heavyInkWords.contains(word), "\(word) must not read as heavy ink")
        }
    }

    // MARK: - Manner × context connections

    func testFindsHeavierInkInTheRain() throws {
        let connections = ContextWeave.connections(days: rainArchive())
        let rainHeavy = try XCTUnwrap(
            connections.first { $0.facetID == "weather:rain" && $0.id.contains("heavy-ink") }
        )
        XCTAssertEqual(rainHeavy.kind, .manner)
        XCTAssertTrue(rainHeavy.line.contains("while it was raining"), rainHeavy.line)
        XCTAssertTrue(rainHeavy.line.contains("five"), "Counts are spelled into the claim: \(rainHeavy.line)")
        XCTAssertEqual(rainHeavy.inHits, 5)
        XCTAssertEqual(rainHeavy.outHits, 0)
        XCTAssertFalse(rainHeavy.evidencePageIDs.isEmpty)
    }

    func testWeatherConnectionNeedsWeatherRecordedOnBothSides() {
        // The dry pages carry no snapshot at all: there is no honest
        // out-group, so the rain claim must stay unspoken.
        let connections = ContextWeave.connections(days: rainArchive(dryWeather: nil))
        XCTAssertFalse(
            connections.contains { $0.facetID.hasPrefix("weather:") },
            "No weather connection without weather recorded on both sides."
        )
    }

    func testStaysQuietWithoutEnoughEvidence() {
        let rainy = (0..<3).map { index in
            page(heavyLine, at: daysAgo(2 + index * 2), id: "rain-\(index)", weather: ["rain"])
        }
        let dry = (0..<8).map { index in
            page(plainLine, at: daysAgo(3 + index * 2), id: "dry-\(index)", weather: ["bright"])
        }
        let connections = ContextWeave.connections(days: days(from: rainy + dry))
        XCTAssertFalse(
            connections.contains { $0.facetID == "weather:rain" },
            "Three pages are a coincidence, not a connection."
        )
    }

    func testFindsQuestionsAfterDarkWithoutAnySnapshots() throws {
        // Hour connections read createdAt, so the whole archive qualifies
        // even before any context snapshots exist.
        let night = (0..<5).map { index in
            page("Why does the house hum louder when everyone sleeps?", at: daysAgo(1 + index * 2, hour: 22), id: "night-\(index)")
        }
        let daytime = (0..<8).map { index in
            page(plainLine, at: daysAgo(2 + index * 2, hour: 9), id: "day-\(index)")
        }
        let connections = ContextWeave.connections(days: days(from: night + daytime))
        let asking = try XCTUnwrap(
            connections.first { $0.facetID == "hour:night" && $0.id.contains("asking") }
        )
        XCTAssertTrue(asking.line.contains("after dark"), asking.line)
    }

    // MARK: - Subject × context connections

    func testFindsSubjectThatOnlyVisitsOnWeekends() throws {
        // now is a Monday: daysAgo(1)/daysAgo(2) are Sunday/Saturday, and a
        // week earlier daysAgo(8)/daysAgo(9) are again.
        let weekend = [1, 2, 8, 9].enumerated().map { index, back in
            page(
                index < 3 ? "The harbor kept its boats folded like letters." : plainLine,
                at: daysAgo(back),
                id: "weekend-\(index)"
            )
        }
        let weekdays = [3, 4, 5, 6, 10, 11, 12].enumerated().map { index, back in
            page(plainLine, at: daysAgo(back, hour: 9 + index % 3), id: "weekday-\(index)")
        }
        let connections = ContextWeave.connections(days: days(from: weekend + weekdays))
        let harbor = try XCTUnwrap(
            connections.first { $0.kind == .subject && $0.facetID == "week:weekend" && $0.id.contains("harbor") }
        )
        XCTAssertTrue(harbor.line.contains("Harbor"), harbor.line)
        XCTAssertTrue(harbor.line.contains("on weekends"), harbor.line)
        XCTAssertTrue(harbor.line.contains("never"), harbor.line)
    }

    func testSubjectSpokenOnWeekdaysTooStaysUnclaimed() {
        let weekend = [1, 2, 8, 9].map { back in
            page("The harbor kept its boats folded like letters.", at: daysAgo(back), id: "weekend-\(back)")
        }
        let weekdays = [3, 4, 5, 6, 10, 11, 12].enumerated().map { index, back in
            page(
                index == 0 ? "Past the harbor on the way to the dentist." : plainLine,
                at: daysAgo(back),
                id: "weekday-\(index)"
            )
        }
        let connections = ContextWeave.connections(days: days(from: weekend + weekdays))
        XCTAssertFalse(
            connections.contains { $0.kind == .subject && $0.id.contains("harbor") },
            "One weekday mention breaks the 'only ever' claim."
        )
    }

    // MARK: - Surfacing through Book Notices

    private func noticeInputs(days: [BookDay]) -> BookSourceInputs {
        var inputs = BookSourceInputs.empty
        inputs.days = days
        return inputs
    }

    func testNoticesAdapterSpeaksTheConnectionWithReceipts() throws {
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: noticeInputs(days: rainArchive()),
            now: now
        )
        let surface = try XCTUnwrap(surfaces.first { $0.payload.metadata["connectionKind"] == "context" })
        XCTAssertTrue(surface.payload.body.contains("while it was raining"), surface.payload.body)
        XCTAssertTrue(surface.payload.body.contains("not diagnosing"), "Observation, never a verdict: \(surface.payload.body)")
        let tags = try XCTUnwrap(surface.payload.metadata["tags"])
        XCTAssertTrue(tags.contains("connection-spoke:context-weather:rain-heavy-ink"), tags)
        XCTAssertNotNil(surface.payload.metadata["tinyPatternCards"], "Evidence cards travel with the claim.")
    }

    func testSpokenConnectionRestsInsteadOfRepeating() throws {
        var archive = rainArchive()
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: []),
            context: CuratorContext.make(for: BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])),
            inputs: noticeInputs(days: archive),
            now: now
        )
        let surface = try XCTUnwrap(surfaces.first { $0.payload.metadata["connectionKind"] == "context" })
        let spokeTag = try XCTUnwrap(
            surface.payload.metadata["tags"]?
                .split(separator: ",")
                .map(String.init)
                .first { $0.hasPrefix("connection-spoke:") }
        )

        // The reader keeps the notice; the spoke tag now lives in the archive.
        let keptNotice = BookPage(
            id: "kept-context-notice",
            type: .bookNotices,
            createdAt: daysAgo(1, hour: 18),
            promptText: "The Book Notices",
            userInput: "",
            tags: ["book-notices", spokeTag]
        )
        if let index = archive.firstIndex(where: { $0.id == BookDay.id(for: keptNotice.createdAt) }) {
            archive[index].pages.append(keptNotice)
        } else {
            archive.append(day(pages: [keptNotice]))
        }

        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let repeated = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: noticeInputs(days: archive),
            now: now
        ).filter { surface in
            surface.payload.metadata["connectionKind"] == "context"
                && (surface.payload.metadata["tags"] ?? "").contains(spokeTag)
        }
        XCTAssertTrue(repeated.isEmpty, "A spoken connection rests; silence beats a rerun.")
    }

    func testKeptPageContextRoundTripsPlaceAndPrivateChartReferences() throws {
        let context = BookPageContextSnapshot(
            at: now,
            weatherTags: ["Rain", "wind"],
            bodyScore: 74,
            calendarEventCount: 3,
            nearbyAnchorID: "front-porch",
            locationLabel: "Home",
            innerWeatherEntryID: "mood-entry-1",
            fuelEntryID: "fuel-entry-1"
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(
            BookPageContextSnapshot.self,
            from: data
        )

        XCTAssertEqual(decoded.weatherTags, ["rain", "wind"])
        XCTAssertEqual(decoded.locationLabel, "Home")
        XCTAssertEqual(decoded.nearbyAnchorID, "front-porch")
        XCTAssertEqual(decoded.innerWeatherEntryID, "mood-entry-1")
        XCTAssertEqual(decoded.fuelEntryID, "fuel-entry-1")
        XCTAssertEqual(decoded.bodyScore, 74)
        XCTAssertEqual(decoded.calendarEventCount, 3)
    }

    // MARK: - Relational Loom: every dimension may meet every other

    private func storyChoicePage(id: String, at date: Date, choice: String) -> BookPage {
        BookPage(
            id: id,
            type: .narrativeOS,
            createdAt: date,
            promptText: "A Story Page",
            userInput: "Chosen path: \(choice.replacingOccurrences(of: "-", with: " "))",
            tags: ["choice:\(choice)"],
            sourceID: "narrative-os",
            origin: .simulated,
            context: BookPageContextSnapshot(at: date)
        )
    }

    private func photographicPage(
        id: String,
        at date: Date,
        palette: String,
        innerWeatherEntryID: String
    ) -> BookPage {
        BookPage(
            id: id,
            type: .plainPage,
            createdAt: date,
            promptText: "Original photograph",
            tags: ["plain-photo"],
            sourceID: "plain-page",
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: date, innerWeatherEntryID: innerWeatherEntryID),
            sensoryFolio: SensoryFolio(observations: [
                SensoryObservation(dimension: .modality, value: "photo", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .palette, value: palette, confidence: 1, extractorID: "test")
            ])
        )
    }

    private func crossMediaPage(
        id: String,
        at date: Date,
        weather: String,
        anchorID: String,
        anchorName: String,
        palette: String,
        cadence: String
    ) -> BookPage {
        BookPage(
            id: id,
            type: .plainPage,
            createdAt: date,
            promptText: "A photograph and a voice note",
            userInput: "A kept cross-media receipt.",
            tags: ["plain-photo"],
            sourceID: "plain-page",
            origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: date,
                weatherTags: [weather],
                nearbyAnchorID: anchorID,
                locationLabel: anchorName
            ),
            sensoryFolio: SensoryFolio(observations: [
                SensoryObservation(dimension: .modality, value: "photo-and-voice", confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .palette, value: palette, confidence: 1, extractorID: "test"),
                SensoryObservation(dimension: .voiceCadence, value: cadence, confidence: 1, extractorID: "test")
            ])
        )
    }

    func testRelationalLoomFindsNightChoosingSliceOfLifeWithoutABespokeRule() throws {
        let night = (0..<5).map { index in
            storyChoicePage(id: "night-slice-\(index)", at: daysAgo(1 + index * 2, hour: 23), choice: "slice-of-life")
        }
        let daylight = (0..<8).map { index in
            storyChoicePage(id: "day-progress-\(index)", at: daysAgo(2 + index * 2, hour: 11), choice: "progress-arc")
        }
        let connections = RelationalLoom.connections(
            days: days(from: night + daylight),
            readerLearning: ReaderLearningModel(),
            facultyEntries: [],
            people: PeopleLedger()
        )
        let found = try XCTUnwrap(connections.first {
            $0.condition.id == "day-part:night" && $0.outcome.id == "choice:slice-of-life"
        })
        XCTAssertEqual(found.inHits, 5)
        XCTAssertEqual(found.outHits, 0)
        XCTAssertTrue(found.line.contains("you chose Slice Of Life"), found.line)
        XCTAssertTrue(found.line.contains("not a cause"), found.line)
    }

    func testRelationalLoomLetsATwoDayCleanLeanSpeakAsAGlimmer() throws {
        let night = (0..<2).map { index in
            storyChoicePage(id: "young-night-slice-\(index)", at: daysAgo(1 + index * 2, hour: 23), choice: "slice-of-life")
        }
        let daylight = (0..<3).map { index in
            storyChoicePage(id: "young-day-progress-\(index)", at: daysAgo(2 + index * 2, hour: 11), choice: "progress-arc")
        }
        let connections = RelationalLoom.connections(
            days: days(from: night + daylight),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: PeopleLedger()
        )
        let glimmer = try XCTUnwrap(connections.first {
            $0.condition.id == "day-part:night" && $0.outcome.id == "choice:slice-of-life"
        })
        XCTAssertEqual(glimmer.evidenceTier, .glimmer)
        XCTAssertTrue(glimmer.line.contains("asking, not announcing"), glimmer.line)
    }

    func testRelationalLoomBuildsAThreeSignalCrossMediaConstellationWithoutABespokeRule() throws {
        let stormHarborNights = (0..<5).map { index in
            crossMediaPage(
                id: "storm-harbor-\(index)", at: daysAgo(1 + index * 2, hour: 23),
                weather: "rain", anchorID: "harbor", anchorName: "Harbor",
                palette: "slate-dark", cadence: "rapid-paused"
            )
        }
        let brightLibraryDays = (0..<8).map { index in
            crossMediaPage(
                id: "bright-library-\(index)", at: daysAgo(2 + index * 2, hour: 11),
                weather: "bright", anchorID: "library", anchorName: "Library",
                palette: "amber-light", cadence: "fluid-slow"
            )
        }
        let connections = RelationalLoom.connections(
            days: days(from: stormHarborNights + brightLibraryDays),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: PeopleLedger()
        )
        let conditionID = "context-blend:day-part:night+place:harbor+weather:rain"
        let constellations = RelationalLoom.constellations(connections: connections)
        let constellation = try XCTUnwrap(constellations.first { $0.condition.id == conditionID })

        let outcomeFamilies = Set(constellation.branches.map { $0.outcome.family })
        XCTAssertTrue(outcomeFamilies.contains(.visualPalette))
        XCTAssertTrue(outcomeFamilies.contains(.voiceCadence))
        XCTAssertTrue(constellation.line.contains("photographic palette leaned slate dark"), constellation.line)
        XCTAssertTrue(constellation.line.contains("voice cadence leaned rapid paused"), constellation.line)
        XCTAssertTrue(constellation.line.contains("tested one by one"), constellation.line)
        XCTAssertEqual(constellation.evidenceTier, .established)
    }

    func testBookNoticesSurfacesTheCrossMediaConstellationWithInspectableBranches() throws {
        let stormHarborNights = (0..<5).map { index in
            crossMediaPage(
                id: "notice-storm-\(index)", at: daysAgo(1 + index * 2, hour: 23),
                weather: "rain", anchorID: "harbor", anchorName: "Harbor",
                palette: "slate-dark", cadence: "rapid-paused"
            )
        }
        let brightLibraryDays = (0..<8).map { index in
            crossMediaPage(
                id: "notice-bright-\(index)", at: daysAgo(2 + index * 2, hour: 11),
                weather: "bright", anchorID: "library", anchorName: "Library",
                palette: "amber-light", cadence: "fluid-slow"
            )
        }
        let today = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: noticeInputs(days: days(from: stormHarborNights + brightLibraryDays)),
            now: now
        )
        let surface = try XCTUnwrap(surfaces.first {
            $0.payload.metadata["connectionKind"] == "relational-constellation"
        })

        let branchCount = try XCTUnwrap(Int(surface.payload.metadata["relationalBranchCount"] ?? ""))
        let outcomes = surface.payload.metadata["relationalOutcomes"] ?? ""
        XCTAssertGreaterThanOrEqual(branchCount, 2)
        XCTAssertTrue(outcomes.contains("Photographic palette"), outcomes)
        XCTAssertTrue(outcomes.contains("Voice cadence"), outcomes)
        XCTAssertFalse((surface.payload.metadata["tinyPatternCards"] ?? "").isEmpty)
        XCTAssertEqual(surface.payload.metadata["feedbackPrompt"], "Do these parts of your Book truly meet here?")
    }

    func testRelationalLoomStillKeepsOneCoincidenceQuiet() {
        let oneNight = [storyChoicePage(id: "one-night", at: daysAgo(1, hour: 23), choice: "slice-of-life")]
        let daylight = (0..<4).map { index in
            storyChoicePage(id: "one-day-\(index)", at: daysAgo(2 + index, hour: 11), choice: "progress-arc")
        }
        let connections = RelationalLoom.connections(
            days: days(from: oneNight + daylight),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: PeopleLedger()
        )
        XCTAssertFalse(connections.contains {
            $0.condition.id == "day-part:night" && $0.outcome.id == "choice:slice-of-life"
        })
    }

    func testRelationalLoomConnectsPhotographicFormOnlyToReaderNamedFeeling() throws {
        let sadEntries = (0..<5).map { index in
            FacultyEntry(
                id: "sad-entry-\(index)", kind: .innerWeather,
                dayID: BookDay.id(for: daysAgo(1 + index * 2)),
                createdAt: daysAgo(1 + index * 2, hour: 8),
                windowID: "morning", windowName: "Morning", rawText: "Sad and low"
            )
        }
        let calmEntries = (0..<8).map { index in
            FacultyEntry(
                id: "calm-entry-\(index)", kind: .innerWeather,
                dayID: BookDay.id(for: daysAgo(2 + index * 2)),
                createdAt: daysAgo(2 + index * 2, hour: 8),
                windowID: "morning", windowName: "Morning", rawText: "Calm and steady"
            )
        }
        let sadPhotos = sadEntries.enumerated().map { index, entry in
            photographicPage(id: "sad-photo-\(index)", at: daysAgo(1 + index * 2, hour: 9), palette: "muted", innerWeatherEntryID: entry.id)
        }
        let calmPhotos = calmEntries.enumerated().map { index, entry in
            photographicPage(id: "calm-photo-\(index)", at: daysAgo(2 + index * 2, hour: 9), palette: "vivid", innerWeatherEntryID: entry.id)
        }
        let connections = RelationalLoom.connections(
            days: days(from: sadPhotos + calmPhotos),
            readerLearning: ReaderLearningModel(),
            facultyEntries: sadEntries + calmEntries,
            people: PeopleLedger()
        )
        let found = try XCTUnwrap(connections.first {
            $0.condition.id == "inner-weather:sad" && $0.outcome.id == "visualPalette:muted"
        })
        XCTAssertEqual(found.headline, "The Weather Behind the Lens")
        XCTAssertTrue(found.line.contains("reader-supplied receipt"), found.line)
    }

    func testRelationalLoomNeverInventsFeelingFromPhotographs() {
        let photos = (0..<13).map { index in
            photographicPage(
                id: "unlinked-photo-\(index)",
                at: daysAgo(index + 1, hour: 9),
                palette: index < 5 ? "muted" : "vivid",
                innerWeatherEntryID: "missing-\(index)"
            )
        }
        let connections = RelationalLoom.connections(
            days: days(from: photos),
            readerLearning: ReaderLearningModel(),
            facultyEntries: [],
            people: PeopleLedger()
        )
        XCTAssertFalse(connections.contains { $0.condition.family == .innerWeather || $0.outcome.family == .innerWeather })
    }

    func testRelationalLoomUsesOpenedInteractionContextForCharacterWeatherConnections() throws {
        var learning = ReaderLearningModel()
        for index in 0..<5 {
            let date = daysAgo(1 + index * 2, hour: 20)
            learning.record(ReaderLearningEvent(
                id: "wicker-open-\(index)", dayID: BookDay.id(for: date), occurredAt: date,
                action: .opened, surfaceID: "wicker-letter-\(index)", sourceID: "letter",
                type: .letter, varietyKey: "sender:wicker-eddies", hour: 20,
                tags: ["sender:wicker-eddies"], evidence: "The letter became readable.",
                context: BookPageContextSnapshot(at: date, weatherTags: ["rain", "cold"])
            ))
        }
        for index in 0..<8 {
            let date = daysAgo(2 + index * 2, hour: 20)
            learning.record(ReaderLearningEvent(
                id: "penny-open-\(index)", dayID: BookDay.id(for: date), occurredAt: date,
                action: .opened, surfaceID: "penny-letter-\(index)", sourceID: "letter",
                type: .letter, varietyKey: "sender:penny-blackletter", hour: 20,
                tags: ["sender:penny-blackletter"], evidence: "The letter became readable.",
                context: BookPageContextSnapshot(at: date, weatherTags: ["bright"])
            ))
        }
        let connections = RelationalLoom.connections(
            days: [], readerLearning: learning, facultyEntries: [], people: PeopleLedger()
        )
        let found = try XCTUnwrap(connections.first {
            $0.condition.id == "weather:cold+rain" && $0.outcome.id == "character:wicker-eddies"
        })
        XCTAssertTrue(found.line.contains("Wicker Eddies"), found.line)
        XCTAssertTrue(found.line.contains("it was raining"), found.line)
    }

    func testRelationalLoomUsesOnlyConfirmedPeopleAsDimensions() throws {
        let samPages = (0..<5).map { index in
            page("Sam and I walked past the harbor and talked for an hour.", at: daysAgo(1 + index * 2), id: "sam-\(index)", weather: ["rain"])
        }
        let alexPages = (0..<8).map { index in
            page("Alex and I made coffee and compared our ridiculous notes.", at: daysAgo(2 + index * 2), id: "alex-\(index)", weather: ["bright"])
        }
        let people = PeopleLedger(threads: [
            PersonThread(id: "person:sam", name: "Sam", introducedDay: "2026-01-01", readerWords: "My friend", firstMentionDay: "2026-01-01", lastMentionDay: "2026-07-01", mentionPageCount: 5),
            PersonThread(id: "person:alex", name: "Alex", introducedDay: "2026-01-01", readerWords: "My friend", firstMentionDay: "2026-01-01", lastMentionDay: "2026-07-01", mentionPageCount: 8)
        ])
        let connections = RelationalLoom.connections(
            days: days(from: samPages + alexPages),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: people
        )
        let found = try XCTUnwrap(connections.first {
            $0.condition.id == "weather:rain" && $0.outcome.id == "person:person:sam"
        })
        XCTAssertTrue(found.line.contains("Sam"), found.line)

        let unconfirmed = RelationalLoom.connections(
            days: days(from: samPages + alexPages),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: PeopleLedger()
        )
        XCTAssertFalse(unconfirmed.contains { $0.condition.family == .person || $0.outcome.family == .person })
    }

    func testRelationalLoomLetsPersistedVectorMeaningMeetEveryOtherDimension() throws {
        let rain = (0..<5).map { index in
            page("A different sentence with enough exact words to remain reader evidence.", at: daysAgo(1 + index * 2), id: "threshold-\(index)", weather: ["rain"])
        }
        let dry = (0..<8).map { index in
            page("Another distinct sentence with enough exact words to remain reader evidence.", at: daysAgo(2 + index * 2), id: "garden-\(index)", weather: ["bright"])
        }
        let threshold = LiteraryContinuitySignal(
            id: "sensory-threshold", kind: .sensory, subjectID: "threshold",
            subjectName: "Thresholds", line: "A local vector joined these Pages.",
            evidencePageIDs: rain.map(\.id), relatedEntityIDs: [], tags: ["sensory"],
            firstSeenAt: rain.first!.createdAt, lastSeenAt: rain.last!.createdAt, strength: 80
        )
        let garden = LiteraryContinuitySignal(
            id: "sensory-garden", kind: .sensory, subjectID: "garden",
            subjectName: "Gardens", line: "Another local vector joined these Pages.",
            evidencePageIDs: dry.map(\.id), relatedEntityIDs: [], tags: ["sensory"],
            firstSeenAt: dry.first!.createdAt, lastSeenAt: dry.last!.createdAt, strength: 80
        )
        let digest = LiteraryContinuityDigest(signals: [threshold, garden], beliefLifecycles: [])
        let connections = RelationalLoom.connections(
            days: days(from: rain + dry),
            readerLearning: ReaderLearningModel(), facultyEntries: [], people: PeopleLedger(),
            continuity: digest
        )
        let found = try XCTUnwrap(connections.first {
            $0.condition.id == "weather:rain" && $0.outcome.id == "meaning:sensory-threshold"
        })
        XCTAssertTrue(found.line.contains("Thresholds"), found.line)
    }

    func testBookRememberedReturnsAReceiptWhenTodayMatchesEvenAGlimmer() throws {
        let rememberedNow = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 23))!
        let night = [1, 3].enumerated().map { index, back in
            storyChoicePage(id: "remember-night-\(index)", at: daysAgo(back, hour: 23), choice: "slice-of-life")
        }
        let daylight = [2, 4, 5].enumerated().map { index, back in
            storyChoicePage(id: "remember-day-\(index)", at: daysAgo(back, hour: 11), choice: "progress-arc")
        }
        var inputs = BookSourceInputs.empty
        inputs.days = days(from: night + daylight)
        inputs.resurfacingCandidates = [night[0]]
        let today = BookDay(
            id: BookDay.id(for: rememberedNow),
            date: Calendar.current.startOfDay(for: rememberedNow),
            pages: []
        )

        let visitation = try XCTUnwrap(BookRememberedEngine.visitation(
            from: inputs.resurfacingCandidates,
            day: today,
            inputs: inputs,
            now: rememberedNow
        ))
        XCTAssertEqual(visitation.page.id, night[0].id)
        XCTAssertTrue(visitation.reason.contains("early connection"), visitation.reason)
        XCTAssertTrue(visitation.reason.contains("Slice Of Life"), visitation.reason)
    }

    func testBookRememberedReturnsAReceiptFromAWholeCrossMediaConstellation() throws {
        let rememberedNow = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 23))!
        let night = (0..<5).map { index in
            crossMediaPage(
                id: "remember-constellation-night-\(index)", at: daysAgo(1 + index * 2, hour: 23),
                weather: "rain", anchorID: "harbor", anchorName: "Harbor",
                palette: "slate-dark", cadence: "rapid-paused"
            )
        }
        let dayPages = (0..<8).map { index in
            crossMediaPage(
                id: "remember-constellation-day-\(index)", at: daysAgo(2 + index * 2, hour: 11),
                weather: "bright", anchorID: "library", anchorName: "Library",
                palette: "amber-light", cadence: "fluid-slow"
            )
        }
        var inputs = BookSourceInputs.empty
        inputs.days = days(from: night + dayPages)
        let today = BookDay(
            id: BookDay.id(for: rememberedNow),
            date: Calendar.current.startOfDay(for: rememberedNow),
            pages: []
        )

        let visitation = try XCTUnwrap(BookRememberedEngine.visitation(
            from: [night[0]], day: today, inputs: inputs, now: rememberedNow
        ))
        XCTAssertEqual(visitation.page.id, night[0].id)
        XCTAssertTrue(visitation.reason.contains("constellation"), visitation.reason)
        XCTAssertTrue(visitation.reason.contains("photographic palette slate dark"), visitation.reason)
        XCTAssertTrue(visitation.reason.contains("voice cadence rapid paused"), visitation.reason)
    }

    func testReaderLearningEventWithoutContextStillDecodes() throws {
        let json = """
        {"id":"old","dayID":"2026-01-01","occurredAt":0,"action":"opened","surfaceID":"s","sourceID":"letter","type":"letter","varietyKey":"sender:wicker-eddies","hour":22,"tags":["sender:wicker-eddies"]}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let event = try decoder.decode(ReaderLearningEvent.self, from: json)
        XCTAssertNil(event.context)
    }
}
