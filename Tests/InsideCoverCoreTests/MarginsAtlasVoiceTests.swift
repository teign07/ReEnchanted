import XCTest
@testable import InsideCoverCore

/// The Margins Atlas has to be read, not decoded. A reader who touches a name
/// on a map should be told what it's tied to in sentences they can check, and
/// every map should have one thing on it they didn't already know.
final class MarginsAtlasVoiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_784_000_000)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func page(_ id: String, _ text: String, hour: Int, dayOffset: Int, weather: [String] = [], place: String? = nil) -> BookPage {
        let at = calendar.date(
            byAdding: .day, value: dayOffset,
            to: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
        )!
        return BookPage(
            id: id, type: .souvenir, createdAt: at, promptText: "Souvenir", userInput: text,
            origin: .userAuthored,
            context: BookPageContextSnapshot(at: at, calendar: calendar, weatherTags: weather, locationLabel: place)
        )
    }

    private func archive(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages, by: { BookDay.id(for: $0.createdAt, calendar: calendar) })
            .map { id, pages in BookDay(id: id, date: calendar.startOfDay(for: pages[0].createdAt), pages: pages) }
            .sorted { $0.date < $1.date }
    }

    /// The kettle only ever in the morning, the lantern only ever at night,
    /// and the harbour wherever.
    private func habits() -> [BookDay] {
        archive([
            page("m1", "The kettle clicked off before the frost left the window.", hour: 7, dayOffset: 0, weather: ["frost"], place: "Home"),
            page("m2", "Frost on the window again, and the kettle going.", hour: 8, dayOffset: 1, weather: ["frost"], place: "Home"),
            page("m3", "The kettle, the frost, the same window, the harbour far off.", hour: 7, dayOffset: 2, weather: ["frost"], place: "Home"),
            page("n1", "Down at the harbour a lantern kept swinging over the jetty.", hour: 22, dayOffset: 0, weather: ["rain"], place: "The Quay"),
            page("n2", "The harbour again, and a lantern on the far jetty.", hour: 23, dayOffset: 1, weather: ["rain"], place: "The Quay"),
            page("n3", "A lantern, a harbour, the jetty entirely empty.", hour: 22, dayOffset: 2, weather: ["rain"], place: "The Quay")
        ])
    }

    // MARK: The surprise

    func testAWordThatOnlyComesOutAtNightIsCalledANightWord() throws {
        let line = try XCTUnwrap(ReaderAtlas.surprise(for: .hours, days: habits(), calendar: calendar))
        XCTAssertTrue(line.contains("only ever turned up at night") || line.contains("only ever turned up in the morning"), line)
        XCTAssertTrue(line.hasSuffix("word."), line)
        XCTAssertFalse(line.contains("harbour"), "the harbour turns up at both times, so it isn't loyal: \(line)")
    }

    func testTheSkiesAndThePlacesHaveTheirOwnSurprises() throws {
        let sky = try XCTUnwrap(ReaderAtlas.surprise(for: .skies, days: habits(), calendar: calendar))
        XCTAssertTrue(sky.contains("on frosty days") || sky.contains("on rainy days"), sky)
        let place = try XCTUnwrap(ReaderAtlas.surprise(for: .places, days: habits(), calendar: calendar))
        XCTAssertTrue(place.contains("when you're at Home") || place.contains("when you're at The Quay"), place)
        XCTAssertTrue(place.hasSuffix("I think it lives there."), place)
    }

    func testTwoWordsThatKeepTurningUpTogetherAreFriends() throws {
        let line = try XCTUnwrap(ReaderAtlas.surprise(for: .lexicon, days: habits(), calendar: calendar))
        XCTAssertTrue(line.hasSuffix("I think they're friends."), line)
    }

    func testNothingIsASurpriseWhenEveryWordTurnsUpEverywhere() {
        let mixed = archive((0..<6).map { index in
            page("p\(index)", "The kettle and the lantern again.", hour: index.isMultiple(of: 2) ? 7 : 22, dayOffset: index)
        })
        XCTAssertNil(ReaderAtlas.surprise(for: .hours, days: mixed, calendar: calendar))
    }

    func testATenderWordIsNeverMadeIntoAJoke() {
        let days = archive((0..<4).map { page("g\($0)", "Grief again, and the kettle.", hour: 23, dayOffset: $0) })
        let line = ReaderAtlas.surprise(for: .hours, days: days, calendar: calendar) ?? ""
        XCTAssertFalse(line.contains("grief"), line)
    }

    // MARK: Touching a name

    func testTouchingAWordSaysWhenItTurnsUpAndHowOften() throws {
        let graph = ReaderAtlas.hours(days: habits(), calendar: calendar)
        let lantern = try XCTUnwrap(graph.nodes.first { $0.label == "lantern" })
        XCTAssertEqual(MarginsAtlasVoice.heading(variant: .hours, node: lantern), "When you write “lantern”:")
        XCTAssertEqual(MarginsAtlasVoice.lines(variant: .hours, node: lantern, graph: graph), ["At night, on 3 Pages"])
        XCTAssertEqual(MarginsAtlasVoice.kindLine(variant: .hours, node: lantern), "One of your own words.")

        let night = try XCTUnwrap(graph.nodes.first { $0.label == "night" })
        XCTAssertEqual(MarginsAtlasVoice.heading(variant: .hours, node: night), "What you write at night:")
        XCTAssertTrue(MarginsAtlasVoice.lines(variant: .hours, node: night, graph: graph).contains("“lantern”, on 3 Pages"))
    }

    func testTheCastAreTiedBySomethingTheyDo() {
        let wicker = GraphNode(id: "wicker", label: "Wicker", weight: 10, chapterID: nil, kindLabel: "character")
        let pippa = GraphNode(id: "pippa", label: "Pippa", weight: 10, chapterID: nil, kindLabel: "character")
        let graph = NarrativeGraphData(nodes: [wicker, pippa], edges: [
            GraphEdge(id: "e", sourceID: "wicker", targetID: "pippa", strength: 0.5, warmth: 0, label: "attention")
        ])
        XCTAssertEqual(MarginsAtlasVoice.lines(variant: .loom, node: pippa, graph: graph), ["Wicker keeps an eye on Pippa."])
        XCTAssertEqual(MarginsAtlasVoice.kindLine(variant: .loom, node: wicker), "One of the Cast.")
    }

    func testBeliefSaysWhoGotIt() {
        let you = GraphNode(id: "the-reader", label: "You", weight: 10, chapterID: nil, kindLabel: "reader")
        let thorne = GraphNode(id: "thorne", label: "Thorne", weight: 10, chapterID: nil, kindLabel: "character")
        let graph = NarrativeGraphData(nodes: [you, thorne], edges: [
            GraphEdge(id: "e", sourceID: "the-reader", targetID: "thorne", strength: 0.5, warmth: 0.4, label: "belief given")
        ])
        XCTAssertEqual(MarginsAtlasVoice.heading(variant: .constellation, node: you), "Where your Belief went:")
        XCTAssertEqual(MarginsAtlasVoice.lines(variant: .constellation, node: you, graph: graph), ["You gave Thorne some of your Belief."])
    }

    /// No filing word reaches a card: no "Glow 12", no raw relationship kinds.
    func testNoCardSpeaksInFilingWords() {
        let kinds = NarrativeRelationshipKind.allCases.map(\.rawValue) + ["disputed", "woven"]
        for kind in kinds {
            XCTAssertNotEqual(MarginsAtlasVoice.loomPhrase(kind), "is tied to", "\(kind) has no words of its own")
        }
        for kind in ["word", "hour", "sky", "place", "thread", "reader", "character", "person", "role", "setting",
                     "channel", "interest", "ritual", "boundary", "season", "page", "artifact", "event"] {
            let node = GraphNode(id: kind, label: kind, weight: 1, chapterID: nil, kindLabel: kind)
            XCTAssertNotEqual(MarginsAtlasVoice.kindLine(variant: .company, node: node), "Something on the map.", kind)
        }
    }

    // MARK: The Atlas's own places

    func testAPlaceKindTakesTheRightArticle() {
        let anchor = AnchorRecord(
            id: "a1", name: "The Corner", latitude: 44, longitude: -69, radiusMeters: 200,
            kind: .notice, belief: 0, created: "2026-03-01", weather: "Rain",
            moon: "waxing", season: "Stick Season", playerWords: "", academyEcho: "",
            outerStacksRoom: "", fae: "", miniStory: "", localRule: "",
            visitCount: 1, lastVisited: "2026-09-01",
            place: AnchorPlaceIdentity(
                name: "Farnsworth", category: "Art Gallery", locality: "Rockland",
                latitude: 44, longitude: -69, matchDistanceMeters: 12, usesRealNameInStory: true
            )
        )
        XCTAssertEqual(Gazetteer.kindLine(for: anchor), "Farnsworth — an art gallery in Rockland.")
    }
}
