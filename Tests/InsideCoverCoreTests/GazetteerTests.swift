import XCTest
@testable import InsideCoverCore

/// Phase 6 of `docs/correspondences-plan.md`. Anchors already held everything a
/// gazetteer needs and none of it was reachable unless the reader was standing
/// within two hundred metres of the place.
final class GazetteerTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func anchor(
        _ id: String,
        name: String,
        visits: Int = 1,
        season: String = "Stick Season",
        weather: String = "Rain",
        place: AnchorPlaceIdentity? = nil
    ) -> AnchorRecord {
        AnchorRecord(
            id: id, name: name, latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: weather,
            moon: "waxing", season: season, playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: visits, lastVisited: "2026-09-01", place: place
        )
    }

    private func identity(
        name: String, category: String, locality: String, real: Bool
    ) -> AnchorPlaceIdentity {
        AnchorPlaceIdentity(
            name: name, category: category, locality: locality,
            latitude: 44, longitude: -69, matchDistanceMeters: 12,
            usesRealNameInStory: real
        )
    }

    private func day(_ id: String, anchorID: String?, wrote: String) -> BookDay {
        let page = BookPage(
            id: "page-\(id)", type: .diary, createdAt: Date(timeIntervalSince1970: 1_780_000_000),
            promptText: "A prompt", userInput: wrote,
            context: BookPageContextSnapshot(nearbyAnchorID: anchorID)
        )
        return BookDay(id: id, date: page.createdAt, pages: [page])
    }

    func testNoAnchorsMeansNoShelf() {
        XCTAssertTrue(Gazetteer.entries(anchors: [], days: []).isEmpty)
    }

    func testAPlaceGathersWhatWasKeptThere() {
        let entries = Gazetteer.entries(
            anchors: [anchor("a1", name: "The Waiting Tree")],
            days: [day("d1", anchorID: "a1", wrote: "A heron, standing still."),
                   day("d2", anchorID: "a1", wrote: "Rained the whole way back."),
                   day("d3", anchorID: "elsewhere", wrote: "Not here at all.")]
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "The Waiting Tree")
        XCTAssertEqual(entries[0].keptCount, 2, "a Page from another place was counted here")
        XCTAssertTrue(entries[0].happenings.contains("A heron, standing still."))
        XCTAssertFalse(entries[0].happenings.contains("Not here at all."))
    }

    func testPlacesWithMoreHistoryComeFirst() {
        let entries = Gazetteer.entries(
            anchors: [anchor("quiet", name: "The Quiet End"), anchor("busy", name: "The Footbridge")],
            days: [day("d1", anchorID: "busy", wrote: "one"), day("d2", anchorID: "busy", wrote: "two"),
                   day("d3", anchorID: "quiet", wrote: "three")]
        )
        XCTAssertEqual(entries.map(\.name), ["The Footbridge", "The Quiet End"])
    }

    /// A place the reader has never written at is still theirs and still
    /// belongs on the shelf.
    func testAPlaceWithNoHistoryStillAppears() {
        let entries = Gazetteer.entries(anchors: [anchor("a1", name: "The Cold Corner")], days: [])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].keptCount, 0)
        XCTAssertTrue(entries[0].happenings.isEmpty)
    }

    // MARK: Veiling

    /// `usesRealNameInStory` is the reader's own decision about whether the Book
    /// may say what a place is really called. The shelf has to keep it.
    func testAVeiledPlaceKeepsItsSecret() {
        let veiled = anchor("a1", name: "My Corner", place: identity(
            name: "Hannaford", category: "supermarket", locality: "Rockland", real: false
        ))
        let entry = Gazetteer.entries(anchors: [veiled], days: [])[0]
        XCTAssertEqual(entry.name, "My Corner", "the reader's own name is always theirs to see")
        let line = entry.kindLine ?? ""
        XCTAssertFalse(line.contains("Hannaford"), "a veiled place leaked its real name")
        XCTAssertFalse(line.contains("Rockland"), "a veiled place leaked its town")
        XCTAssertTrue(line.contains("supermarket"), "the category is not the secret")
    }

    func testAnUnveiledPlaceIsNamedProperly() {
        let open = anchor("a1", name: "My Corner", place: identity(
            name: "Hannaford", category: "supermarket", locality: "Rockland", real: true
        ))
        let line = Gazetteer.entries(anchors: [open], days: [])[0].kindLine ?? ""
        XCTAssertTrue(line.contains("Hannaford"))
        XCTAssertTrue(line.contains("Rockland"))
    }

    func testAPlaceMapsNeverMatchedHasNoKindLine() {
        XCTAssertNil(Gazetteer.entries(anchors: [anchor("a1", name: "The Gap")], days: [])[0].kindLine)
    }

    // MARK: What the Book says about it

    func testTheMakingIsRemembered() {
        let line = Gazetteer.entries(anchors: [anchor("a1", name: "x")], days: [])[0].madeLine ?? ""
        XCTAssertTrue(line.contains("Stick Season"))
        XCTAssertTrue(line.contains("rain"))
    }

    /// The first time was not a return, and "one visit" of a place you made
    /// yourself is a silly thing to say.
    func testTheBookCountsReturnsNotVisits() {
        XCTAssertNil(Gazetteer.entries(anchors: [anchor("a", name: "x", visits: 1)], days: [])[0].returnsLine)
        XCTAssertEqual(
            Gazetteer.entries(anchors: [anchor("a", name: "x", visits: 2)], days: [])[0].returnsLine,
            "You've been back once."
        )
        XCTAssertEqual(
            Gazetteer.entries(anchors: [anchor("a", name: "x", visits: 5)], days: [])[0].returnsLine,
            "You've been back 4 times."
        )
    }

    /// A happening is the reader's own words. The Book's prose about a place is
    /// not a memory of the place.
    func testAHappeningPrefersTheReadersOwnWords() {
        let written = BookPage(
            id: "p", type: .diary, createdAt: Date(), promptText: "The Book asked something",
            userInput: "I saw the fox again."
        )
        XCTAssertEqual(Gazetteer.happening(written), "I saw the fox again.")

        let unanswered = BookPage(
            id: "q", type: .diary, createdAt: Date(), promptText: "The Book asked something",
            userInput: "   "
        )
        XCTAssertEqual(Gazetteer.happening(unanswered), "The Book asked something")
    }

    func testALongHappeningIsClipped() {
        let page = BookPage(
            id: "p", type: .diary, createdAt: Date(), promptText: "",
            userInput: String(repeating: "a", count: 400)
        )
        let line = Gazetteer.happening(page) ?? ""
        XCTAssertLessThanOrEqual(line.count, 160)
        XCTAssertTrue(line.hasSuffix("…"))
    }

    func testTheContentsLineCarriesNoCount() {
        XCTAssertFalse(Gazetteer.contentsDetail.contains { $0.isNumber })
    }
}
