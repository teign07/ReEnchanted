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
        XCTAssertGreaterThanOrEqual(span?.latitudeSpan ?? 0, 0.4)
        XCTAssertGreaterThanOrEqual(span?.longitudeSpan ?? 0, 0.4)
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
