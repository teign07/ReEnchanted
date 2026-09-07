import XCTest
@testable import InsideCoverCore

/// Phase 8 of `docs/correspondences-plan.md`, and the part bj asked to be
/// expandable: layers arrive from outside, so local lore or an errand can put
/// something on the map later without the map learning about them.
final class AtlasTests: XCTestCase {

    private func anchor(_ id: String, _ name: String, lat: Double = 44, lon: Double = -69) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: lat, longitude: lon, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 3, lastVisited: "2026-09-01"
        )
    }

    private func day(_ id: String, lat: Double?, lon: Double?, wrote: String) -> BookDay {
        let page = BookPage(
            id: "p-\(id)", type: .diary, createdAt: Date(),
            promptText: "", userInput: wrote,
            context: BookPageContextSnapshot(latitude: lat, longitude: lon)
        )
        return BookDay(id: id, date: page.createdAt, pages: [page])
    }

    // MARK: The shape that makes it expandable

    /// Every registered layer must actually declare itself. A layer with no
    /// title or note is one somebody added without deciding what it is.
    func testEveryRegisteredLayerSaysWhatItIs() {
        for source in AtlasProjection.registered {
            XCTAssertFalse(source.title.isEmpty, "\(source.layer.rawValue) has no title")
            XCTAssertFalse(source.note.isEmpty, "\(source.layer.rawValue) has no note")
            XCTAssertFalse(source.glyph.isEmpty, "\(source.layer.rawValue) has no glyph")
        }
    }

    func testLayerIdentifiersAreUnique() {
        var ids: [String] = []
        for source in AtlasProjection.registered { ids.append(source.layer.rawValue) }
        XCTAssertEqual(Set(ids).count, ids.count, "two layers share an id: \(ids)")
    }

    /// The registry is the extension point. A new layer is one type and one
    /// line here, and the map itself never learns its name.
    func testANewLayerNeedsNothingFromTheMap() {
        let lore = AtlasLayer(
            id: AtlasLayerID("local-lore"),
            title: "What is said about here",
            note: "Things people tell each other about this ground.",
            glyph: "book.closed",
            isOnByDefault: false,
            marks: [AtlasMark(
                id: "lore:1", layer: AtlasLayerID("local-lore"),
                latitude: 44, longitude: -69, title: "The drowned lane",
                subtitle: nil, glyph: "drop.fill", detail: ["They say it floods every March."], weight: 5
            )]
        )
        let shown = AtlasProjection.marks(in: [lore], showing: [AtlasLayerID("local-lore")])
        XCTAssertEqual(shown.count, 1)
        XCTAssertTrue(AtlasProjection.marks(in: [lore], showing: []).isEmpty)
    }

    // MARK: Composition

    func testAnEmptyWorldDrawsNoLayers() {
        XCTAssertTrue(AtlasProjection.layers(from: AtlasSources()).isEmpty)
    }

    func testPlacesBecomeMarks() {
        let layers = AtlasProjection.layers(from: AtlasSources(
            anchors: [anchor("a1", "The Waiting Tree")], days: []
        ))
        let places = layers.first { $0.id == .places }
        XCTAssertNotNil(places)
        XCTAssertEqual(places?.marks.first?.title, "The Waiting Tree")
        XCTAssertEqual(places?.isOnByDefault, true, "the reader's own places should be on when the map opens")
    }

    /// Pages only carry coordinates if they were kept after the archive was
    /// allowed to remember where it was. An old archive drawing nothing here is
    /// correct, not a bug.
    func testPagesWithoutCoordinatesDrawNothing() {
        let layers = AtlasProjection.layers(from: AtlasSources(
            anchors: [], days: [day("d1", lat: nil, lon: nil, wrote: "somewhere")]
        ))
        XCTAssertNil(layers.first { $0.id == .kept })
    }

    func testPagesWithCoordinatesBecomeMarks() {
        let layers = AtlasProjection.layers(from: AtlasSources(
            anchors: [], days: [day("d1", lat: 44.1, lon: -69.1, wrote: "A heron.")]
        ))
        let kept = layers.first { $0.id == .kept }
        XCTAssertEqual(kept?.marks.count, 1)
        XCTAssertEqual(kept?.marks.first?.detail.first, "A heron.")
        XCTAssertEqual(kept?.isOnByDefault, false, "the busy layer should not be on by default")
    }

    /// A mark with a broken coordinate is not drawn at the wrong place, it is
    /// not drawn.
    func testImpossibleCoordinatesAreNotPlaced() {
        let layers = AtlasProjection.layers(from: AtlasSources(
            anchors: [anchor("bad", "Nowhere", lat: 991, lon: -69)], days: []
        ))
        XCTAssertTrue(layers.isEmpty)
    }

    // MARK: Framing

    func testAnEmptyMapHasNothingToFrame() {
        XCTAssertNil(AtlasProjection.span(of: []))
    }

    /// A map framed to a single mark would open inside the pin.
    func testASingleMarkStillGetsAFewStreets() {
        let span = AtlasProjection.span(of: [AtlasMark(
            id: "m", layer: .places, latitude: 44, longitude: -69,
            title: "t", subtitle: nil, glyph: "x", detail: [], weight: 1
        )])
        XCTAssertEqual(span?.latitude ?? 0, 44, accuracy: 0.0001)
        XCTAssertGreaterThan(span?.latitudeSpan ?? 0, 0)
        XCTAssertGreaterThan(span?.longitudeSpan ?? 0, 0)
    }

    func testTheFrameHoldsEverything() {
        let marks = [
            AtlasMark(id: "a", layer: .places, latitude: 44.0, longitude: -69.0,
                      title: "a", subtitle: nil, glyph: "x", detail: [], weight: 1),
            AtlasMark(id: "b", layer: .places, latitude: 44.4, longitude: -68.6,
                      title: "b", subtitle: nil, glyph: "x", detail: [], weight: 1)
        ]
        let span = AtlasProjection.span(of: marks)
        XCTAssertEqual(span?.latitude ?? 0, 44.2, accuracy: 0.0001)
        // Capped now: the frame holds what it can without opening on a
        // continent. Anything wider is a pinch away.
        XCTAssertLessThanOrEqual(span?.latitudeSpan ?? 0, AtlasProjection.widestOpeningSpan)
        XCTAssertGreaterThanOrEqual(span?.latitudeSpan ?? 0, AtlasProjection.neighbourhoodSpan)
    }

    /// Veiling is decided once, in the Gazetteer, and the map inherits it
    /// rather than making the decision a second time.
    func testTheMapInheritsVeilingRatherThanRedecidingIt() {
        var veiled = anchor("a1", "My Corner")
        veiled.place = AnchorPlaceIdentity(
            name: "Hannaford", category: "supermarket", locality: "Rockland",
            latitude: 44, longitude: -69, matchDistanceMeters: 10,
            usesRealNameInStory: false
        )
        let layers = AtlasProjection.layers(from: AtlasSources(anchors: [veiled], days: []))
        let mark = layers.first { $0.id == .places }?.marks.first
        XCTAssertEqual(mark?.title, "My Corner")
        let text = ([mark?.subtitle].compactMap { $0 } + (mark?.detail ?? [])).joined(separator: " ")
        XCTAssertFalse(text.contains("Hannaford"), "the map leaked a veiled name")
        XCTAssertFalse(text.contains("Rockland"), "the map leaked a veiled town")
    }
}

/// Phase 7: the plates. The privacy rule lives in the spec rather than in the
/// renderer, so it is decided once and testable without a single map tile.
final class MapPlateTests: XCTestCase {

    private func anchor(_ id: String = "a1", veiled: Bool? = nil, lat: Double = 44, lon: Double = -69) -> AnchorRecord {
        var record = AnchorRecord(
            id: id, name: "The Waiting Tree", latitude: lat, longitude: lon,
            radiusMeters: 200, kind: .notice, belief: 0, created: "2026-03-01",
            weather: "Rain", moon: "waxing", season: "Stick Season",
            playerWords: "", academyEcho: "", outerStacksRoom: "", fae: "",
            miniStory: "", localRule: "", visitCount: 1, lastVisited: "2026-09-01"
        )
        if let veiled {
            record.place = AnchorPlaceIdentity(
                name: "Hannaford", category: "supermarket", locality: "Rockland",
                latitude: lat, longitude: lon, matchDistanceMeters: 10,
                usesRealNameInStory: !veiled
            )
        }
        return record
    }

    func testAPlateNeedsAUsableCoordinate() {
        XCTAssertNil(MapPlate.spec(for: anchor(lat: 991)))
        XCTAssertNotNil(MapPlate.spec(for: anchor()))
    }

    /// A plate is not wallpaper. It carries the place and whatever the reader
    /// kept around it.
    func testAPlateCarriesThePlaceAndWhatHappenedThere() {
        let kept = [AtlasMark(
            id: "k", layer: .kept, latitude: 44.001, longitude: -69.001,
            title: "", subtitle: nil, glyph: "circle.fill", detail: [], weight: 1
        )]
        let spec = MapPlate.spec(for: anchor(), kept: kept)
        XCTAssertEqual(spec?.marks.count, 2)
        XCTAssertEqual(spec?.marks.first?.isPrimary, true)
        XCTAssertEqual(spec?.marks.last?.isPrimary, false)
    }

    // MARK: The rule that matters

    func testAnOpenPlaceIsDrawnPreciselyOnScreen() {
        let spec = MapPlate.spec(for: anchor(veiled: false))
        XCTAssertEqual(spec?.isLoosened, false)
        XCTAssertEqual(spec?.showsLabels, true)
        XCTAssertEqual(spec?.latitude ?? 0, 44, accuracy: 0.000001, "an open plate was moved off its place")
        XCTAssertEqual(spec?.latitudeSpan ?? 0, MapPlate.tightSpan, accuracy: 0.000001)
    }

    func testAVeiledPlaceIsLoosenedAndUnlabelled() {
        let spec = MapPlate.spec(for: anchor(veiled: true))
        XCTAssertEqual(spec?.isLoosened, true)
        XCTAssertEqual(spec?.showsLabels, false, "a veiled plate kept its street names")
        XCTAssertGreaterThan(spec?.latitudeSpan ?? 0, MapPlate.tightSpan)
        XCTAssertNotEqual(spec?.latitude ?? 0, 44, "a loosened plate still sat on the place")
    }

    /// Print goes through this app's backend and then to a printer. A plate
    /// centred on somebody's door at street zoom is a doxxing vector however
    /// carefully the rest of the Page was written — so print is always loosened,
    /// whatever the reader chose for their own screen.
    func testPrintIsAlwaysLoosenedEvenForAnOpenPlace() {
        let spec = MapPlate.spec(for: anchor(veiled: false), destination: .print)
        XCTAssertEqual(spec?.isLoosened, true)
        XCTAssertEqual(spec?.showsLabels, false)
        XCTAssertGreaterThan(spec?.latitudeSpan ?? 0, MapPlate.tightSpan)
    }

    func testPrintIsLoosenedForAPlaceMapsNeverMatched() {
        let spec = MapPlate.spec(for: anchor(), destination: .print)
        XCTAssertEqual(spec?.isLoosened, true)
    }

    /// Scattering the reader's kept Pages across a district is the pattern the
    /// loosening exists to break up, so a loosened plate carries only the place.
    func testALoosenedPlateDoesNotPlotEverythingTheReaderDid() {
        let kept = (0..<5).map { index in
            AtlasMark(id: "k\(index)", layer: .kept, latitude: 44 + Double(index) / 1000,
                      longitude: -69, title: "", subtitle: nil, glyph: "x", detail: [], weight: 1)
        }
        let spec = MapPlate.spec(for: anchor(veiled: true), kept: kept)
        XCTAssertEqual(spec?.marks.count, 1, "a loosened plate plotted the reader's movements")
    }

    /// The nudge has to be stable, or the plate wanders every redraw.
    func testTheLooseningIsStablePerPlace() {
        let first = MapPlate.spec(for: anchor(veiled: true))
        let second = MapPlate.spec(for: anchor(veiled: true))
        XCTAssertEqual(first, second)

        let other = MapPlate.spec(for: anchor("a2", veiled: true))
        XCTAssertNotEqual(first?.latitude, other?.latitude, "every loosened plate is nudged identically")
    }

    /// The nudge must stay inside the frame, or the place falls off its own plate.
    func testTheNudgeStaysInsideTheChart() {
        for index in 0..<300 {
            let spec = MapPlate.spec(for: anchor("place-\(index)", veiled: true))
            let drift = abs((spec?.latitude ?? 0) - 44)
            XCTAssertLessThan(drift, (spec?.latitudeSpan ?? 0) / 2, "place-\(index) fell off its own plate")
        }
    }

    func testScreenAndPrintPlatesAreCachedApart() {
        XCTAssertNotEqual(
            MapPlate.spec(for: anchor(), destination: .screen)?.id,
            MapPlate.spec(for: anchor(), destination: .print)?.id,
            "a print plate could be served from the screen plate's cache"
        )
    }

    func testTheGazetteerHandsEachPlaceItsPlate() {
        let entries = Gazetteer.entries(anchors: [anchor()], days: [])
        XCTAssertNotNil(entries.first?.plate, "a place reached the shelf without a chart")
        XCTAssertEqual(entries.first?.plate?.marks.first?.isPrimary, true)
    }
}

/// The quiet leaf: a place come across between two Pages rather than looked up.
final class QuietLeafPlaceTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func anchor(_ id: String, name: String, lastVisitedDaysAgo: Int) -> AnchorRecord {
        let visited = calendar.date(byAdding: .day, value: -lastVisitedDaysAgo, to: now) ?? now
        return AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 2,
            lastVisited: AnchorRegistry.visitDateFormatter.string(from: visited)
        )
    }

    /// Hours are spread deliberately. Building every Page at the same timestamp
    /// gives the fixture an accidental pattern, and the hour noticing then fires
    /// on a place that has none — which is what happened the first time.
    private func days(_ anchorID: String, count: Int) -> [BookDay] {
        let hours = [8, 13, 19, 23, 10, 16]
        return (0..<count).map { index in
            let hour = hours[index % hours.count]
            let stamped = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            let page = BookPage(
                id: "p\(index)-\(anchorID)", type: .diary, createdAt: stamped,
                promptText: "", userInput: "something \(index)",
                context: BookPageContextSnapshot(
                    at: stamped, calendar: calendar, nearbyAnchorID: anchorID
                )
            )
            return BookDay(id: "d\(index)-\(anchorID)", date: stamped, pages: [page])
        }
    }

    func testNoPlacesMeansNoLeaf() {
        XCTAssertNil(Gazetteer.quietLeaf(anchors: [], days: [], now: now, calendar: calendar))
    }

    /// The point of the whole thing: somewhere that dropped out of the reader's
    /// week is exactly the shape of what this app argues with, so it wins.
    func testAPlaceGoneQuietOutranksABusyOne() {
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("busy", name: "The Footbridge", lastVisitedDaysAgo: 1),
                      anchor("quiet", name: "The Waiting Tree", lastVisitedDaysAgo: 200)],
            days: days("busy", count: 6) + days("quiet", count: 2),
            now: now, calendar: calendar
        )
        XCTAssertEqual(leaf?.anchorID, "quiet")
        XCTAssertTrue(leaf?.line.contains("haven't been back") == true, "got: \(leaf?.line ?? "nil")")
    }

    /// A place gone quiet that nothing ever happened at is not a loss, it is an
    /// anchor the reader made once and never used.
    func testAQuietPlaceWithNoHistoryIsNotMourned() {
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("quiet", name: "The Cold Corner", lastVisitedDaysAgo: 300)],
            days: [], now: now, calendar: calendar
        )
        XCTAssertFalse(leaf?.line.contains("haven't been back") ?? false)
    }

    func testABusyPlaceIsRaisedForItsHistory() {
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("busy", name: "The Footbridge", lastVisitedDaysAgo: 2)],
            days: days("busy", count: 4), now: now, calendar: calendar
        )
        XCTAssertTrue(leaf?.line.contains("4 things") == true, "got: \(leaf?.line ?? "nil")")
    }

    func testTheLeafIsStableWithinADay() {
        let anchors = [anchor("a", name: "A", lastVisitedDaysAgo: 3),
                       anchor("b", name: "B", lastVisitedDaysAgo: 4)]
        let first = Gazetteer.quietLeaf(anchors: anchors, days: [], now: now, dayID: "d1", calendar: calendar)
        let second = Gazetteer.quietLeaf(anchors: anchors, days: [], now: now, dayID: "d1", calendar: calendar)
        XCTAssertEqual(first?.anchorID, second?.anchorID, "the leaf changed under the reader's thumb")
    }

    /// "Forty-seven days" is a stopwatch. The Book is not one.
    func testTheBookRoundsToMonths() {
        XCTAssertEqual(Gazetteer.months(46), "a month")
        XCTAssertEqual(Gazetteer.months(75), "2 months")
        XCTAssertEqual(Gazetteer.months(400), "13 months")
    }

    func testAnUnreadableVisitDateIsNotTreatedAsAncient() {
        var broken = anchor("x", name: "X", lastVisitedDaysAgo: 300)
        broken.lastVisited = "not a date"
        XCTAssertNil(Gazetteer.daysSinceVisit(broken, now: now, calendar: calendar))
    }

    func testTheLeafAlwaysCarriesAChartAndAReason() {
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("a", name: "The Waiting Tree", lastVisitedDaysAgo: 90)],
            days: days("a", count: 2), now: now, calendar: calendar
        )
        XCTAssertFalse(leaf?.line.isEmpty ?? true, "a place was raised with no reason given")
        XCTAssertFalse(leaf?.title.isEmpty ?? true)
        XCTAssertEqual(leaf?.plate.marks.first?.isPrimary, true)
    }
}

/// The noticings: shapes the Book finds in the reader's own record and says
/// plainly, without moralising and without claiming more than it knows.
final class PlaceNoticingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func anchor(_ id: String, name: String, quietDays: Int = 1) -> AnchorRecord {
        let visited = calendar.date(byAdding: .day, value: -quietDays, to: now) ?? now
        return AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 2,
            lastVisited: AnchorRegistry.visitDateFormatter.string(from: visited)
        )
    }

    private func page(_ id: String, anchorID: String, weather: [String] = [], hour: Int = 14) -> BookPage {
        let stamped = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        return BookPage(
            id: id, type: .diary, createdAt: stamped, promptText: "", userInput: "x",
            context: BookPageContextSnapshot(
                at: stamped, calendar: calendar,
                weatherTags: weather, nearbyAnchorID: anchorID
            )
        )
    }

    private func days(_ pages: [BookPage]) -> [BookDay] {
        pages.enumerated().map { BookDay(id: "d\($0.offset)", date: now, pages: [$0.element]) }
    }

    // MARK: One weather

    /// The Book knows what the reader *kept*, not where they went — so it never
    /// says "you've never been here in the rain". It says the true version.
    func testAPlaceAlwaysKeptInOneWeather() {
        let pages = (0..<3).map { page("p\($0)", anchorID: "a", weather: ["rain"]) }
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("a", name: "The Footbridge")], days: days(pages),
            now: now, calendar: calendar
        )
        XCTAssertEqual(leaf?.line, "Every time you've kept something here, it has been raining.")
    }

    func testTwoVisitsIsNotAPattern() {
        let pages = (0..<2).map { page("p\($0)", anchorID: "a", weather: ["rain"]) }
        XCTAssertNil(Gazetteer.sharedWeather(of: pages))
    }

    func testAMixedRecordIsNotAPattern() {
        let mixed = [page("p0", anchorID: "a", weather: ["rain"]),
                     page("p1", anchorID: "a", weather: ["rain"]),
                     page("p2", anchorID: "a", weather: ["bright"])]
        XCTAssertNil(Gazetteer.sharedWeather(of: mixed))
    }

    /// A Page kept before the Book recorded weather cannot vouch for anything.
    func testAPageWithNoWeatherBreaksTheClaim() {
        let pages = [page("p0", anchorID: "a", weather: ["rain"]),
                     page("p1", anchorID: "a", weather: ["rain"]),
                     page("p2", anchorID: "a", weather: [])]
        XCTAssertNil(Gazetteer.sharedWeather(of: pages))
    }

    func testAWeatherWithNoPhraseSaysNothing() {
        let pages = (0..<3).map { page("p\($0)", anchorID: "a", weather: ["cloud"]) }
        XCTAssertNil(Gazetteer.sharedWeather(of: pages))
    }

    // MARK: One hour

    func testAPlaceOnlyEverStoppedAtAfterDark() {
        let pages = (0..<3).map { page("p\($0)", anchorID: "a", hour: 23) }
        let leaf = Gazetteer.quietLeaf(
            anchors: [anchor("a", name: "The Footbridge")], days: days(pages),
            now: now, calendar: calendar
        )
        XCTAssertEqual(leaf?.line, "You've only ever stopped here after dark.")
    }

    func testAPlaceVisitedAtAllHoursIsNotAPattern() {
        let spread = [page("p0", anchorID: "a", hour: 9),
                      page("p1", anchorID: "a", hour: 14),
                      page("p2", anchorID: "a", hour: 23)]
        XCTAssertNil(Gazetteer.sharedHour(of: spread))
    }

    // MARK: Several places at once

    /// One place gone quiet is a gap. Several at once is a season of a life the
    /// reader has moved out of, and the Book should say the larger true thing.
    func testSeveralPlacesGoneQuietIsSaidAsTheLargerThing() {
        let anchors = ["a", "b", "c"].map { anchor($0, name: "Place \($0)", quietDays: 120) }
        let pages = anchors.map { page("p-\($0.id)", anchorID: $0.id, weather: ["rain"]) }
        let leaf = Gazetteer.quietLeaf(
            anchors: anchors, days: days(pages), now: now, calendar: calendar
        )
        XCTAssertTrue(leaf?.line.contains("2 other places") == true, "got: \(leaf?.line ?? "nil")")
    }

    func testOneQuietPlaceIsStillSaidAsOne() {
        let quiet = anchor("a", name: "The Waiting Tree", quietDays: 120)
        let busy = anchor("b", name: "The Footbridge", quietDays: 2)
        let leaf = Gazetteer.quietLeaf(
            anchors: [quiet, busy],
            days: days([page("p0", anchorID: "a"), page("p1", anchorID: "b")]),
            now: now, calendar: calendar
        )
        XCTAssertTrue(leaf?.line.contains("still on the chart") == true, "got: \(leaf?.line ?? "nil")")
    }

    /// Going quiet outranks a weather pattern: the Book says the thing that
    /// matters most, not the cleverest thing it has.
    func testGoingQuietOutranksTheOtherNoticings() {
        let quiet = anchor("a", name: "The Waiting Tree", quietDays: 200)
        let pages = (0..<4).map { page("p\($0)", anchorID: "a", weather: ["rain"]) }
        let leaf = Gazetteer.quietLeaf(
            anchors: [quiet], days: days(pages), now: now, calendar: calendar
        )
        XCTAssertTrue(leaf?.line.contains("haven't been back") == true, "got: \(leaf?.line ?? "nil")")
    }
}

/// Plates in a bound edition. These decide what gets printed, so they are the
/// tests that matter most: a page in a book cannot be taken back.
final class EditionPlateTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let windowStart = Date(timeIntervalSince1970: 1_785_000_000)
    private let windowEnd = Date(timeIntervalSince1970: 1_787_600_000)

    private func anchor(_ id: String, _ name: String, lat: Double = 44, lon: Double = -69) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: lat, longitude: lon, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 1, lastVisited: "2026-09-01"
        )
    }

    private func day(_ id: String, anchorID: String, at: Date) -> BookDay {
        let page = BookPage(
            id: "p-\(id)", type: .diary, createdAt: at, promptText: "", userInput: "x",
            context: BookPageContextSnapshot(nearbyAnchorID: anchorID)
        )
        return BookDay(id: id, date: at, pages: [page])
    }

    // MARK: The allowance

    /// A week has no atlas. A year is a life.
    func testTheAllowanceGrowsWithTheSpan() {
        XCTAssertEqual(MapPlate.signatureAllowance(for: .weekly), 0)
        XCTAssertLessThan(
            MapPlate.signatureAllowance(for: .monthly),
            MapPlate.signatureAllowance(for: .seasonal)
        )
        XCTAssertLessThan(
            MapPlate.signatureAllowance(for: .seasonal),
            MapPlate.signatureAllowance(for: .annual)
        )
    }

    func testTheAllowanceIsHonouredExactly() {
        let anchors = (0..<12).map { anchor("a\($0)", "Place \($0)") }
        let days = anchors.map { day("d-\($0.id)", anchorID: $0.id, at: windowEnd) }
        let plates = MapPlate.signaturePlaces(
            anchors: anchors, days: days, from: windowStart, to: windowEnd, kind: .monthly
        )
        XCTAssertEqual(plates.count, MapPlate.signatureAllowance(for: .monthly))
    }

    func testAWeeklyGathersNoPlatesAtAll() {
        let anchors = [anchor("a", "Place")]
        XCTAssertTrue(MapPlate.signaturePlaces(
            anchors: anchors, days: [day("d", anchorID: "a", at: windowEnd)],
            from: windowStart, to: windowEnd, kind: .weekly
        ).isEmpty)
    }

    // MARK: What earns a plate

    /// A chart of somewhere nothing happened this month is padding, and padding
    /// is what a printed book can least afford.
    func testOnlyPlacesSomethingHappenedAtEarnAPlate() {
        let used = anchor("used", "The Footbridge")
        let idle = anchor("idle", "The Cold Corner")
        let plates = MapPlate.signaturePlaces(
            anchors: [used, idle], days: [day("d", anchorID: "used", at: windowEnd)],
            from: windowStart, to: windowEnd, kind: .annual
        )
        XCTAssertEqual(plates.map(\.anchor.id), ["used"])
    }

    /// The window is the edition's own. A Page kept last year does not earn a
    /// place a plate in this month's book.
    func testPagesOutsideTheWindowDoNotCount() {
        let before = windowStart.addingTimeInterval(-86_400 * 30)
        let after = windowEnd.addingTimeInterval(86_400 * 30)
        let plates = MapPlate.signaturePlaces(
            anchors: [anchor("a", "Place")],
            days: [day("early", anchorID: "a", at: before), day("late", anchorID: "a", at: after)],
            from: windowStart, to: windowEnd, kind: .annual
        )
        XCTAssertTrue(plates.isEmpty)
    }

    func testTheBusiestPlaceLeadsTheSignature() {
        let quiet = anchor("quiet", "The Quiet End")
        let busy = anchor("busy", "The Footbridge")
        let days = [day("d1", anchorID: "quiet", at: windowEnd)]
            + (0..<3).map { day("b\($0)", anchorID: "busy", at: windowEnd) }
        let plates = MapPlate.signaturePlaces(
            anchors: [quiet, busy], days: days, from: windowStart, to: windowEnd, kind: .annual
        )
        XCTAssertEqual(plates.first?.anchor.id, "busy")
        XCTAssertEqual(plates.first?.keptCount, 3)
    }

    // MARK: The endpaper

    func testNoPlacesMeansNoEndpaper() {
        XCTAssertNil(MapPlate.endpaperSpec(anchors: []))
    }

    func testTheEndpaperHoldsEveryPlace() {
        let anchors = [anchor("a", "A", lat: 44.0, lon: -69.0),
                       anchor("b", "B", lat: 44.5, lon: -68.5)]
        let spec = MapPlate.endpaperSpec(anchors: anchors)
        XCTAssertEqual(spec?.marks.count, 2)
        XCTAssertEqual(spec?.latitude ?? 0, 44.25, accuracy: 0.0001)
        // Wide enough to hold them, and capped so the endpaper never becomes an
        // aerial photograph of a country with a few dots on it.
        XCTAssertGreaterThan(spec?.latitudeSpan ?? 0, MapPlate.tightSpan)
        XCTAssertLessThanOrEqual(spec?.latitudeSpan ?? 0, AtlasProjection.widestOpeningSpan)
    }

    /// This page goes through a backend and a print house on its way to a
    /// shelf. A reader with one Anchor must not get a printed chart of their
    /// own doorstep.
    func testAnEndpaperIsAlwaysLoosenedEvenForOnePlace() {
        let spec = MapPlate.endpaperSpec(anchors: [anchor("a", "Home")])
        XCTAssertEqual(spec?.isLoosened, true)
        XCTAssertEqual(spec?.showsLabels, false)
        XCTAssertGreaterThanOrEqual(spec?.latitudeSpan ?? 0, MapPlate.tightSpan * MapPlate.looseningFactor)
    }

    func testAnImpossibleCoordinateIsLeftOffTheEndpaper() {
        let spec = MapPlate.endpaperSpec(anchors: [anchor("ok", "Fine"), anchor("bad", "Nowhere", lat: 991)])
        XCTAssertEqual(spec?.marks.count, 1)
    }

    func testTheCaptionSuitsHowManyPlacesThereAre() {
        XCTAssertTrue(MapPlate.endpaperCaption(placeCount: 1, readerName: "bj").contains("one place"))
        XCTAssertTrue(MapPlate.endpaperCaption(placeCount: 3, readerName: "bj").contains("3 places"))
        XCTAssertTrue(MapPlate.endpaperCaption(placeCount: 40, readerName: "bj").contains("40"))
    }
}

/// Where a chart opens. It used to open on `.automatic` with nothing to frame,
/// which gives a continent.
final class AtlasOpeningTests: XCTestCase {

    private func mark(_ id: String, lat: Double, lon: Double) -> AtlasMark {
        AtlasMark(id: id, layer: .places, latitude: lat, longitude: lon,
                  title: id, subtitle: nil, glyph: "x", detail: [], weight: 1)
    }

    /// Somebody opening the Atlas wants to see where they are.
    func testItOpensOnTheReaderWhenItKnowsWhereTheyAre() {
        let far = [mark("a", lat: 34, lon: -118), mark("b", lat: 44, lon: -69)]
        let opening = AtlasProjection.opening(marks: far, readerLatitude: 44.1, readerLongitude: -69.1)
        XCTAssertEqual(opening?.latitude ?? 0, 44.1, accuracy: 0.0001)
        XCTAssertEqual(opening?.latitudeSpan ?? 0, AtlasProjection.neighbourhoodSpan, accuracy: 0.0001)
    }

    func testAnImpossibleReadingIsIgnored() {
        let opening = AtlasProjection.opening(
            marks: [mark("a", lat: 44, lon: -69)], readerLatitude: 991, readerLongitude: -69
        )
        XCTAssertEqual(opening?.latitude ?? 0, 44, accuracy: 0.0001)
    }

    /// One Anchor left behind on a trip away should not turn the chart into an
    /// aerial view of a country with six dots on it.
    func testTheChartNeverOpensOnAContinent() {
        let coastToCoast = [mark("west", lat: 34, lon: -118), mark("east", lat: 44, lon: -69)]
        let opening = AtlasProjection.opening(marks: coastToCoast, readerLatitude: nil, readerLongitude: nil)
        XCTAssertLessThanOrEqual(opening?.latitudeSpan ?? 99, AtlasProjection.widestOpeningSpan)
        XCTAssertLessThanOrEqual(opening?.longitudeSpan ?? 99, AtlasProjection.widestOpeningSpan)
    }

    /// A median centre keeps the frame where the reader's life is, rather than
    /// halfway to the one place they visited once.
    func testTheFrameSitsOnTheClusterNotBetweenTheExtremes() {
        let cluster = (0..<5).map { mark("c\($0)", lat: 44 + Double($0) / 1000, lon: -69) }
        let outlier = [mark("far", lat: 34, lon: -69)]
        let opening = AtlasProjection.opening(marks: cluster + outlier, readerLatitude: nil, readerLongitude: nil)
        XCTAssertGreaterThan(opening?.latitude ?? 0, 43, "the outlier dragged the frame off the cluster")
    }

    func testAnEmptyChartFramesNothing() {
        XCTAssertNil(AtlasProjection.opening(marks: [], readerLatitude: nil, readerLongitude: nil))
    }

    /// The endpaper is capped and centred the same way, for the same reason.
    func testTheEndpaperIsCappedToo() {
        let anchors = [
            AnchorRecord(id: "w", name: "West", latitude: 34, longitude: -118, radiusMeters: 200,
                         kind: .notice, belief: 0, created: "", weather: "", moon: "", season: "",
                         playerWords: "", academyEcho: "", outerStacksRoom: "", fae: "", miniStory: "",
                         localRule: "", visitCount: 1, lastVisited: ""),
            AnchorRecord(id: "e", name: "East", latitude: 44, longitude: -69, radiusMeters: 200,
                         kind: .notice, belief: 0, created: "", weather: "", moon: "", season: "",
                         playerWords: "", academyEcho: "", outerStacksRoom: "", fae: "", miniStory: "",
                         localRule: "", visitCount: 1, lastVisited: "")
        ]
        let spec = MapPlate.endpaperSpec(anchors: anchors)
        XCTAssertLessThanOrEqual(spec?.latitudeSpan ?? 99, AtlasProjection.widestOpeningSpan)
    }
}

/// A weekly gets where *this week* happened. The world endpaper belongs to
/// editions that arrive rarely enough for it to still be a surprise.
final class WeeklyChartScopeTests: XCTestCase {

    private let windowStart = Date(timeIntervalSince1970: 1_785_000_000)
    private let windowEnd = Date(timeIntervalSince1970: 1_787_600_000)

    private func anchor(_ id: String) -> AnchorRecord {
        AnchorRecord(
            id: id, name: id, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "", weather: "", moon: "", season: "",
            playerWords: "", academyEcho: "", outerStacksRoom: "", fae: "",
            miniStory: "", localRule: "", visitCount: 1, lastVisited: ""
        )
    }

    private func day(_ anchorID: String, at: Date) -> BookDay {
        let page = BookPage(
            id: "p-\(anchorID)-\(at.timeIntervalSince1970)", type: .diary, createdAt: at,
            promptText: "", userInput: "x",
            context: BookPageContextSnapshot(nearbyAnchorID: anchorID)
        )
        return BookDay(id: page.id, date: at, pages: [page])
    }

    func testOnlyThePlacesTheWeekTouchedAreCharted() {
        let active = MapPlate.placesActive(
            anchors: [anchor("used"), anchor("idle")],
            days: [day("used", at: windowEnd)],
            from: windowStart, to: windowEnd
        )
        XCTAssertEqual(active.map(\.id), ["used"])
    }

    func testAPlaceTouchedOutsideTheWeekIsNotCharted() {
        let active = MapPlate.placesActive(
            anchors: [anchor("a")],
            days: [day("a", at: windowStart.addingTimeInterval(-86_400 * 14))],
            from: windowStart, to: windowEnd
        )
        XCTAssertTrue(active.isEmpty)
    }

    /// A week with no places charts nothing, rather than reprinting the world.
    func testAQuietWeekChartsNothing() {
        XCTAssertTrue(MapPlate.placesActive(
            anchors: [anchor("a")], days: [], from: windowStart, to: windowEnd
        ).isEmpty)
    }

    func testAWeeklyStillGathersNoPlateSignature() {
        XCTAssertEqual(MapPlate.signatureAllowance(for: .weekly), 0)
    }
}
