import XCTest
@testable import InsideCoverCore

/// The Margins Atlas was a three-card deck, and all three cards drew the
/// *world*: the cast, where Belief went, the people the reader names. Measured
/// over a fortnight it reached the desk ten to twelve times out of three
/// distinct Pages, because three is how many maps existed.
///
/// These are the maps of the reader. Every edge has to be something they
/// actually did — this word, under that sky, at that hour — and every one of
/// these tests is really the same test: does the Book refuse to draw when it
/// does not have the evidence?
final class ReaderAtlasTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_784_000_000)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func page(
        _ id: String,
        _ text: String,
        hour: Int,
        dayOffset: Int = 0,
        weather: [String] = [],
        place: String? = nil
    ) -> BookPage {
        let at = calendar.date(
            byAdding: .day, value: dayOffset,
            to: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
        )!
        return BookPage(
            id: id,
            type: .souvenir,
            createdAt: at,
            promptText: "Souvenir",
            userInput: text,
            origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: at,
                calendar: calendar,
                weatherTags: weather,
                locationLabel: place
            )
        )
    }

    private func archive(_ pages: [BookPage]) -> [BookDay] {
        Dictionary(grouping: pages, by: { BookDay.id(for: $0.createdAt, calendar: calendar) })
            .map { id, pages in
                BookDay(id: id, date: calendar.startOfDay(for: pages[0].createdAt), pages: pages)
            }
            .sorted { $0.date < $1.date }
    }

    /// A reader who writes about kettles in the morning and harbours at night.
    private func twoHabits() -> [BookDay] {
        archive([
            page("m1", "The kettle clicked off before the frost left the window.", hour: 7),
            page("m2", "Frost on the window again, and the kettle going in the dark.", hour: 8, dayOffset: 1),
            page("m3", "The kettle, the frost, the same window.", hour: 7, dayOffset: 2),
            page("n1", "Down at the harbour a lantern kept swinging over the jetty.", hour: 22),
            page("n2", "The harbour again, and a lantern on the far jetty.", hour: 23, dayOffset: 1),
            page("n3", "A lantern, a harbour, the jetty entirely empty.", hour: 22, dayOffset: 2)
        ])
    }

    // MARK: - The hours

    func testTheHoursMapDrawsWhatTheReaderBringsToEachPartOfTheDay() {
        let graph = ReaderAtlas.hours(days: twoHabits(), calendar: calendar)

        XCTAssertGreaterThanOrEqual(graph.edges.count, ReaderAtlas.minimumEdges)
        let hours = Set(graph.nodes.filter { $0.kindLabel == "hour" }.map(\.label))
        XCTAssertTrue(hours.contains("morning"), "hours were \(hours)")
        XCTAssertTrue(hours.contains("night"), "hours were \(hours)")

        // The claim is specific: the kettle belongs to the morning and the
        // lantern to the night, and the map must not cross them.
        let morningWords = graph.edges
            .filter { $0.sourceID == "hour-morning" }
            .map(\.targetID)
        XCTAssertTrue(morningWords.contains("word-kettle"), "morning drew \(morningWords)")
        XCTAssertFalse(morningWords.contains("word-lantern"), "morning drew \(morningWords)")
    }

    /// One column is not a map. A reader who only ever writes at breakfast has
    /// no hours worth drawing, and the Book should say nothing rather than
    /// present a single habit as a finding.
    func testASingleHabitIsNotAMap() {
        let onlyMornings = archive([
            page("m1", "The kettle clicked off before dawn.", hour: 7),
            page("m2", "A kettle, and frost on the window.", hour: 8, dayOffset: 1),
            page("m3", "Frost again, and the kettle in the dark.", hour: 7, dayOffset: 2)
        ])

        XCTAssertTrue(ReaderAtlas.hours(days: onlyMornings, calendar: calendar).edges.isEmpty)
    }

    // MARK: - The weather and the ground

    func testTheSkiesMapNeedsTheWeatherToHaveChanged() {
        let mixed = archive([
            page("r1", "Rain on the skylight, and the kettle going.", hour: 9, weather: ["rain"]),
            page("r2", "The kettle again, and the skylight streaming.", hour: 14, dayOffset: 1, weather: ["rain"]),
            page("c1", "Clear enough to see the harbour and the jetty.", hour: 9, dayOffset: 2, weather: ["clear"]),
            page("c2", "The harbour, the jetty, no cloud at all.", hour: 15, dayOffset: 3, weather: ["clear"])
        ])
        let graph = ReaderAtlas.skies(days: mixed, calendar: calendar)

        XCTAssertGreaterThanOrEqual(graph.edges.count, ReaderAtlas.minimumEdges)
        let skies = Set(graph.nodes.filter { $0.kindLabel == "sky" }.map(\.label))
        XCTAssertEqual(skies, ["rain", "clear"])

        let oneSky = archive([
            page("r1", "Rain on the skylight, and the kettle going.", hour: 9, weather: ["rain"]),
            page("r2", "The kettle again, and the skylight streaming.", hour: 14, dayOffset: 1, weather: ["rain"])
        ])
        XCTAssertTrue(
            ReaderAtlas.skies(days: oneSky, calendar: calendar).edges.isEmpty,
            "one kind of sky is not a weather map"
        )
    }

    func testTheGroundMapDrawsWhereTheReaderWasStanding() {
        let travelled = archive([
            page("h1", "The harbour had a lantern on every post along the jetty.", hour: 10, place: "Portland"),
            page("h2", "A lantern, the jetty, and the harbour going quiet.", hour: 11, dayOffset: 1, place: "Portland"),
            page("k1", "The kitchen kettle, and frost on the window.", hour: 9, dayOffset: 2, place: "Home"),
            page("k2", "Frost again, and the kettle at the window.", hour: 8, dayOffset: 3, place: "Home")
        ])
        let graph = ReaderAtlas.places(days: travelled, calendar: calendar)

        XCTAssertGreaterThanOrEqual(graph.edges.count, ReaderAtlas.minimumEdges)
        XCTAssertEqual(
            Set(graph.nodes.filter { $0.kindLabel == "place" }.map(\.label)),
            ["Portland", "Home"]
        )
    }

    // MARK: - The reader's own vocabulary

    func testTheLexiconMapIsMadeOnlyOfTheReadersOwnWords() {
        let graph = ReaderAtlas.lexicon(days: twoHabits(), calendar: calendar)

        XCTAssertGreaterThanOrEqual(graph.edges.count, ReaderAtlas.minimumEdges)
        XCTAssertTrue(graph.nodes.allSatisfy { $0.kindLabel == "word" })
        let words = Set(graph.nodes.map(\.label))
        XCTAssertTrue(words.contains("kettle"), "words were \(words)")
        XCTAssertTrue(words.contains("harbour"), "words were \(words)")
        // Nothing the reader did not write may appear on a map of their words.
        XCTAssertFalse(words.contains("morning"))
    }

    /// A word that appeared once is not a pattern. Recurrence is the entire
    /// claim these maps make, so a single vivid page must draw nothing.
    func testOneVividPageIsNotAVocabulary() {
        let once = archive([
            page("p1", "A kestrel over the reservoir, and thunder behind it.", hour: 9),
            page("p2", "Nothing much. Slept badly.", hour: 10, dayOffset: 1)
        ])

        XCTAssertTrue(ReaderAtlas.lexicon(days: once, calendar: calendar).edges.isEmpty)
    }

    /// The Book's own braid is not the reader writing, and an empty archive is
    /// not a map of anything.
    func testTheBookDoesNotDrawItselfIntoTheReadersMaps() {
        let braid = BookPage(
            id: "braid", type: .bookOfYou, createdAt: start,
            promptText: "The Book of You",
            userInput: "The kettle and the harbour and the lantern and the kettle.",
            usedInBookOfYou: true, origin: .generated
        )
        XCTAssertTrue(ReaderAtlas.lexicon(days: archive([braid]), calendar: calendar).edges.isEmpty)
        XCTAssertTrue(ReaderAtlas.hours(days: [], calendar: calendar).edges.isEmpty)
        XCTAssertTrue(ReaderAtlas.lexicon(days: [], calendar: calendar).edges.isEmpty)
    }

    /// The deck the whole exercise was for: the Atlas used to be three cards.
    func testTheAtlasNowHasMoreThanThreeMapsToDraw() {
        XCTAssertGreaterThan(MarginsAtlasVariant.allCases.count, 3)
        for variant in MarginsAtlasVariant.allCases {
            XCTAssertFalse(variant.title.isEmpty)
            XCTAssertFalse(variant.detail.isEmpty)
            XCTAssertFalse(variant.openingLine.isEmpty)
        }
    }
}
