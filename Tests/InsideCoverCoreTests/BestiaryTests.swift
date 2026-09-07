import XCTest
@testable import InsideCoverCore

/// The filing system. Perception has been finding animals for months and
/// throwing them away; these are the rules for what gets kept and what doesn't,
/// because a shelf that files a catfish under cats is worse than no shelf.
final class BestiaryFilingTests: XCTestCase {

    private func fact(
        _ label: String,
        _ confidence: Double,
        kind: VisualFactKind = .setting,
        source: VisualFactSource = .appleVisionClassifier
    ) -> VisualFact {
        VisualFact(kind: kind, label: label, confidence: confidence, source: source)
    }

    // MARK: What counts as alive

    func testTheDedicatedRecognizersAnimalsAreFiled() {
        let packet = VisualFactPacket(facts: [
            fact("Cat", 0.94, kind: .animal, source: .appleVisionAnimal)
        ])
        XCTAssertEqual(
            Bestiary.sightings(in: packet),
            [CreatureSighting(creature: "cat", certainty: .clear)]
        )
    }

    /// The classifier's taxonomy is full of animals the dedicated pass can't
    /// see. It only knows cats and dogs; the whole rest of the bestiary comes
    /// from labels that arrive as plain scene tags.
    func testAClassifierLabelCanNameACreature() {
        let packet = VisualFactPacket(facts: [fact("crow", 0.8)])
        XCTAssertEqual(Bestiary.sightings(in: packet).first?.creature, "crow")
    }

    func testThingsThatAreNotAliveAreNotFiled() {
        let packet = VisualFactPacket(facts: [
            fact("bicycle", 0.9), fact("kitchen", 0.9), fact("sunset", 0.9)
        ])
        XCTAssertTrue(Bestiary.sightings(in: packet).isEmpty)
    }

    /// The reason the match is on the whole label and never a substring. A
    /// reader who finds a catfish filed under cats stops trusting the shelf,
    /// and they'd be right to.
    func testACatfishIsNotACat() {
        XCTAssertNil(Bestiary.creature(for: "catfish"))
        XCTAssertNil(Bestiary.creature(for: "dogwood"))
        XCTAssertNil(Bestiary.creature(for: "hot dog"))
        XCTAssertNil(Bestiary.creature(for: "catkin"))
    }

    // MARK: How sure the Book has to be

    /// Perception hands up labels from 0.16 because a weak label is still
    /// useful context for a caption. It is not enough to put an animal on a
    /// shelf and say it was there.
    func testAMaybeIsNotFiled() {
        let packet = VisualFactPacket(facts: [fact("owl", 0.2)])
        XCTAssertTrue(Bestiary.sightings(in: packet).isEmpty)
        XCTAssertEqual(VisualCertainty(confidence: 0.2), .possible)
    }

    func testAProbablyIsFiled() {
        let packet = VisualFactPacket(facts: [fact("owl", 0.5)])
        XCTAssertEqual(
            Bestiary.sightings(in: packet),
            [CreatureSighting(creature: "owl", certainty: .likely)]
        )
    }

    // MARK: One animal, several passes

    /// The dedicated recognizer and the classifier both see the one cat. Two
    /// passes agreeing is agreement, not a second animal.
    func testTwoPassesNamingTheSameAnimalFileItOnce() {
        let packet = VisualFactPacket(facts: [
            fact("cat", 0.4),
            fact("Cat", 0.95, kind: .animal, source: .appleVisionAnimal)
        ])
        XCTAssertEqual(Bestiary.sightings(in: packet).count, 1)
        XCTAssertEqual(Bestiary.sightings(in: packet).first?.certainty, .clear)
    }

    /// A puppy really is a dog, and the Book can defend that merge out loud.
    func testTheFewDefensibleMergesHappen() {
        XCTAssertEqual(Bestiary.creature(for: "puppy"), "dog")
        XCTAssertEqual(Bestiary.creature(for: "kitten"), "cat")
        XCTAssertEqual(Bestiary.creature(for: "lamb"), "sheep")
    }

    /// Nothing collapses a specific creature into a general one. "Bird" is a
    /// duller thing to have seen than a songbird, and the shelf is for the
    /// interesting version.
    func testSpecificCreaturesAreNotFlattenedIntoGeneralOnes() {
        XCTAssertEqual(Bestiary.creature(for: "songbird"), "songbird")
        XCTAssertEqual(Bestiary.creature(for: "kingfisher"), "kingfisher")
        XCTAssertEqual(Bestiary.creature(for: "tortoise"), "tortoise")
    }

    func testTheOrderIsStable() {
        let packet = VisualFactPacket(facts: [
            fact("heron", 0.5), fact("fox", 0.9), fact("bee", 0.5)
        ])
        XCTAssertEqual(
            Bestiary.sightings(in: packet).map(\.creature),
            ["fox", "bee", "heron"],
            "surest first, then alphabetical, so the same photo files the same way twice"
        )
    }

    func testAnEmptyPacketFilesNothingRatherThanFailing() {
        XCTAssertTrue(Bestiary.sightings(in: VisualFactPacket()).isEmpty)
    }

    // MARK: Carrying it onto the page

    func testSightingsSurviveTheTripThroughPageMetadata() {
        let sightings = [
            CreatureSighting(creature: "fox", certainty: .clear),
            CreatureSighting(creature: "heron", certainty: .likely)
        ]
        XCTAssertEqual(Bestiary.decoded(Bestiary.encoded(sightings)), sightings)
    }

    func testAnEmptyMetadataStringDecodesToNothing() {
        XCTAssertTrue(Bestiary.decoded("").isEmpty)
    }

    func testAMetadataStringMissingItsCertaintyStillNamesTheCreature() {
        XCTAssertEqual(Bestiary.decoded("fox").first?.creature, "fox")
    }
}

/// The archive side. `PhotoAnalysis` is decoded straight out of a language
/// model's JSON, so both the absence of the field and a model's opinions about
/// it have to be handled before anything reaches a shelf.
final class CreatureRecordTests: XCTestCase {

    private var analysis: PhotoAnalysis { .academyFallback }

    /// Nobody looking is a different fact from looking and finding nothing. A
    /// shelf that can't tell them apart would eventually tell the reader they
    /// have photographed no animals on the strength of pages from before the
    /// detector ran at all.
    func testNothingLookedIsNotTheSameAsNothingSeen() {
        XCTAssertNil(analysis.creatures, "an unexamined photo claims nothing")
        var looked = analysis
        looked.creatures = []
        XCTAssertEqual(looked.creatures, [])
    }

    /// The whole reason `creatures` is optional rather than defaulted-empty: a
    /// non-optional property with a default still throws on a missing key, and
    /// Gemma's JSON will never mention this field.
    func testAnAnalysisWithoutCreaturesStillDecodes() throws {
        // The template id comes from the type rather than a literal: this test
        // is about a missing key, and a stale raw value would fail it for the
        // wrong reason.
        let template = PhotoAnalysis.academyFallback.suggestedTemplate.rawValue
        let json = """
        {"scene":"A quiet yard.","motifs":["yard"],"mood":"quiet",
         "suggestedTemplate":"\(template)",
         "marginalia":{"fieldNote":"n","stampLabel":"s",
                       "observationList":["a"],"closingLine":"c"},
         "souvenirCandidates":["one"]}
        """
        let decoded = try JSONDecoder().decode(PhotoAnalysis.self, from: Data(json.utf8))
        XCTAssertNil(decoded.creatures)
    }

    /// A model that decides to mention a wolf must not be able to put one in
    /// the archive. The bestiary is a record of what a detector saw.
    func testTheValidatorRefusesACreatureTheFilingSystemDoesNotKnow() {
        var invented = analysis
        invented.creatures = [
            CreatureSighting(creature: "fox", certainty: .clear),
            CreatureSighting(creature: "the watcher in the hedge", certainty: .clear)
        ]
        let validated = PhotoAnalysisValidator.validate(invented, fallback: .academyFallback)
        XCTAssertEqual(validated.creatures?.map(\.creature), ["fox"])
    }

    func testTheValidatorKeepsNothingLookedAsNothingLooked() {
        let validated = PhotoAnalysisValidator.validate(analysis, fallback: .academyFallback)
        XCTAssertNil(validated.creatures)
    }

    func testSightingsReachThePageAndComeBack() {
        var read = analysis
        read.creatures = [CreatureSighting(creature: "crow", certainty: .likely)]
        let metadata = [Bestiary.metadataKey: Bestiary.encoded(read.creatures ?? [])]
        let recovered = PhotoAnalysis.fromSurfaceMetadata(metadata, fallback: .academyFallback)
        XCTAssertEqual(recovered.creatures, read.creatures)
    }
}

/// The shelf. A creature's history is the Pages it appears on, so these are
/// tests about reading the archive rather than about keeping a second ledger.
final class BestiaryShelfTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    /// 2026-08-29.
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    /// The hour is a parameter because leaving it constant hands every fixture
    /// an accidental pattern, and the hour noticing then fires on a set of
    /// Pages that has none. That has already happened once in this codebase.
    private func date(_ year: Int, _ month: Int, _ day: Int = 12, hour: Int = 14) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? now
    }

    private func page(
        _ id: String,
        _ creatures: [CreatureSighting]?,
        at when: Date,
        anchorID: String? = nil,
        weather: [String] = []
    ) -> BookPage {
        BookPage(
            id: id, type: .enchantment, createdAt: when, promptText: "", userInput: "x",
            context: BookPageContextSnapshot(
                at: when, calendar: calendar, weatherTags: weather, nearbyAnchorID: anchorID
            ),
            creatureSightings: creatures
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        pages.enumerated().map { BookDay(id: "d\($0.offset)", date: $0.element.createdAt, pages: [$0.element]) }
    }

    private func anchor(_ id: String, _ name: String) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 1, lastVisited: "2026-08-01"
        )
    }

    private func fox(_ certainty: VisualCertainty = .clear) -> [CreatureSighting] {
        [CreatureSighting(creature: "fox", certainty: certainty)]
    }

    // MARK: Grouping

    func testOneCreatureAcrossSeveralPhotographsIsOneEntry() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(), at: date(2026, 3)),
            page("b", fox(), at: date(2026, 4)),
            page("c", fox(), at: date(2026, 5))
        ]), now: now, calendar: calendar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.count, 3)
    }

    func testTheMostSeenCreatureLeads() {
        let entries = Bestiary.entries(days: days([
            page("a", [CreatureSighting(creature: "heron", certainty: .clear)], at: date(2026, 3)),
            page("b", fox(), at: date(2026, 4)),
            page("c", fox(), at: date(2026, 5))
        ]), now: now, calendar: calendar)
        XCTAssertEqual(entries.map(\.creature), ["fox", "heron"])
    }

    /// A creature glimpsed once and later seen properly is still one creature,
    /// and the Book gets to stop hedging about it.
    func testTheSurestSightingSetsTheCertainty() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(.likely), at: date(2026, 3)),
            page("b", fox(.clear), at: date(2026, 4))
        ]), now: now, calendar: calendar)
        XCTAssertEqual(entries.first?.certainty, .clear)
    }

    // MARK: When

    func testOnceIsSaidAsOnce() {
        XCTAssertEqual(
            Bestiary.seenLine(count: 1, first: date(2026, 3), last: date(2026, 3), now: now, calendar: calendar),
            "Once, in March."
        )
    }

    func testSightingsInsideOneMonthStayInThatMonth() {
        XCTAssertEqual(
            Bestiary.seenLine(count: 3, first: date(2026, 3, 2), last: date(2026, 3, 28), now: now, calendar: calendar),
            "3 times, all in March."
        )
    }

    func testSightingsAcrossMonthsSpanThem() {
        XCTAssertEqual(
            Bestiary.seenLine(count: 7, first: date(2026, 3), last: date(2026, 8), now: now, calendar: calendar),
            "7 times, from March to August."
        )
    }

    /// The year is noise when it's this one and necessary when it isn't.
    func testTheYearIsOnlySaidWhenItIsNotThisOne() {
        XCTAssertEqual(Bestiary.monthLabel(date(2026, 3), now: now, calendar: calendar), "March")
        XCTAssertEqual(Bestiary.monthLabel(date(2024, 3), now: now, calendar: calendar), "March 2024")
    }

    /// The same month in a different year is not the same month.
    func testTheSameMonthInAnotherYearIsNotOneMonth() {
        let line = Bestiary.seenLine(
            count: 2, first: date(2025, 3), last: date(2026, 3), now: now, calendar: calendar
        )
        XCTAssertEqual(line, "Twice, from March 2025 to March.")
    }

    // MARK: Where

    /// The reader's own name for a place is the only place-word the Book prints
    /// without asking. Never a street, never a business.
    func testAPlaceSeenEveryTimeIsSaidAsAlways() {
        XCTAssertEqual(
            Bestiary.whereLine(places: ["The Footbridge", "The Footbridge", "The Footbridge"], count: 3),
            "Always at The Footbridge."
        )
    }

    func testOneSightingAtOnePlaceIsNotAPattern() {
        XCTAssertEqual(Bestiary.whereLine(places: ["The Footbridge"], count: 1), "At The Footbridge.")
    }

    func testTwoPlacesAreBothNamed() {
        XCTAssertEqual(
            Bestiary.whereLine(places: ["The Footbridge", "The Waiting Tree"], count: 2),
            "At The Footbridge and The Waiting Tree."
        )
    }

    func testManyPlacesNameTwoAndCountTheRest() {
        XCTAssertEqual(
            Bestiary.whereLine(places: ["A", "B", "C", "D"], count: 4),
            "At A, B, and 2 other places you've named."
        )
    }

    func testAPhotographTakenNowhereNamedSaysNothingAboutWhere() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(), at: date(2026, 3))
        ]), now: now, calendar: calendar)
        XCTAssertNil(entries.first?.whereLine)
    }

    func testAnAnchorTheReaderNamedReachesTheCard() {
        let entries = Bestiary.entries(
            days: days([page("a", fox(), at: date(2026, 3), anchorID: "f")]),
            anchors: [anchor("f", "The Footbridge")],
            now: now, calendar: calendar
        )
        XCTAssertEqual(entries.first?.whereLine, "At The Footbridge.")
    }

    // MARK: The noticings, borrowed

    /// The place noticings turn out not to be about places at all. They read a
    /// set of Pages, and a creature is a set of Pages.
    func testAPatternInTheWeatherIsNoticedAboutACreatureToo() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(), at: date(2026, 3), weather: ["rain"]),
            page("b", fox(), at: date(2026, 4), weather: ["rain"]),
            page("c", fox(), at: date(2026, 5), weather: ["rain"])
        ]), now: now, calendar: calendar)
        XCTAssertEqual(entries.first?.noticing, "Every time, it has been raining.")
    }

    /// Hours are spread as deliberately as the weather is mixed: this test is
    /// about a creature with no pattern, and a fixture that accidentally has
    /// one tests nothing.
    func testNoPatternMeansNoNoticing() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(), at: date(2026, 3, hour: 9), weather: ["rain"]),
            page("b", fox(), at: date(2026, 4, hour: 14), weather: ["bright"]),
            page("c", fox(), at: date(2026, 5, hour: 23), weather: ["snow"])
        ]), now: now, calendar: calendar)
        XCTAssertNil(entries.first?.noticing)
    }

    /// The hour noticing reaches creatures too, and it should: something you
    /// only ever see after dark is a different animal from one you see at noon.
    func testAnHourPatternIsNoticedAboutACreature() {
        let entries = Bestiary.entries(days: days([
            page("a", fox(), at: date(2026, 3, hour: 23)),
            page("b", fox(), at: date(2026, 4, hour: 22)),
            page("c", fox(), at: date(2026, 5, hour: 1))
        ]), now: now, calendar: calendar)
        XCTAssertEqual(entries.first?.noticing, "Only ever after dark.")
    }

    // MARK: Nobody looked

    /// The shelf has two empty states and only one of them is the reader's to
    /// fix. Telling somebody they've photographed no animals on the strength of
    /// pages from before the detector ran would be the Book blaming them for
    /// its own blindness.
    func testPagesNobodyLookedAtAreNotCountedAsLookedAt() {
        let looked = days([
            page("a", [], at: date(2026, 3)),
            page("b", [], at: date(2026, 4))
        ])
        let unexamined = days([page("c", nil, at: date(2026, 5))])
        XCTAssertEqual(Bestiary.photographsExamined(in: looked), 2)
        XCTAssertEqual(Bestiary.photographsExamined(in: unexamined), 0)
        XCTAssertTrue(Bestiary.entries(days: looked + unexamined, now: now, calendar: calendar).isEmpty)
    }

    func testAnEmptyArchiveShelvesNothing() {
        XCTAssertTrue(Bestiary.entries(days: [], now: now, calendar: calendar).isEmpty)
    }

    /// A sighting has to survive being written down and read back, or the shelf
    /// is only ever as good as the session that filled it.
    func testASightingSurvivesTheArchive() throws {
        let page = page("a", fox(), at: date(2026, 3))
        let encoded = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(BookPage.self, from: encoded)
        XCTAssertEqual(decoded.creatureSightings, fox())
    }

    func testAPageFromBeforeTheBestiaryStillDecodes() throws {
        var old = page("a", nil, at: date(2026, 3))
        old.creatureSightings = nil
        let encoded = try JSONEncoder().encode(old)
        XCTAssertNil(try JSONDecoder().decode(BookPage.self, from: encoded).creatureSightings)
    }
}
