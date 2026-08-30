import XCTest
@testable import InsideCoverCore

/// The Sentence Runner is built out of the reader's own kept phrases and needs
/// six of them before it will open at all. It had stopped appearing entirely,
/// and the cause was not curation — it was never becoming a candidate.
///
/// `phraseCandidates` kept a short sentence *whole* on length alone, and a
/// later filter then discarded anything over seven words. So a plainly written
/// eight-word line under fifty-two characters passed the first test, failed the
/// second, and contributed nothing. Only sentences long enough to be truncated
/// to four words survived. A reader who writes short and plain could never
/// reach six.
final class SentenceRunnerSupplyTests: XCTestCase {
    private var calendar: Calendar {
        var v = Calendar(identifier: .gregorian); v.timeZone = TimeZone(secondsFromGMT: 0)!; return v
    }
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    /// Every one of these is under fifty-two characters and over seven words:
    /// exactly the shape that used to vanish.
    private let plainAndShort = [
        "Rain came sideways across the car park at noon.",
        "The bus was late and nobody minded very much.",
        "A gull took a chip out of my hand.",
        "Someone left a chair out in the wet snow.",
        "The hall light hums when the heating comes on.",
        "The dog next door barked at a bag again.",
        "Steam on the mirror had spelled out nothing much.",
        "There were blackberries out, and it is still August."
    ]

    private func archive(_ lines: [String]) -> [BookDay] {
        var days: [BookDay] = []
        for (index, line) in lines.enumerated() {
            let at = now.addingTimeInterval(-Double(lines.count - index) * 86_400)
            days.append(BookDay(
                id: BookDay.id(for: at, calendar: calendar),
                date: calendar.startOfDay(for: at),
                pages: [BookPage(
                    id: "p\(index)", type: .souvenir, createdAt: at,
                    promptText: "Souvenir", userInput: line, origin: .userAuthored
                )]
            ))
        }
        return days
    }

    func testAReaderWhoWritesShortPlainSentencesCanStillPlay() {
        var inputs = BookSourceInputs.empty
        inputs.days = archive(plainAndShort)
        inputs.resurfacingCandidates = inputs.days.flatMap(\.pages)
        let today = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])

        let pages = GamePageSourceAdapter().candidates(
            for: today, context: .make(for: today), inputs: inputs, now: now
        )

        XCTAssertFalse(
            pages.isEmpty,
            "eight short plain sentences produced no phrases, so the runner never opened"
        )
        XCTAssertEqual(pages.first?.type, .gamePage)
    }

    /// The ceiling itself still has to hold: the game shows phrases, not
    /// paragraphs, so nothing long may slip through whole.
    func testThePhrasesTheGameOffersStayShort() {
        var inputs = BookSourceInputs.empty
        inputs.days = archive(plainAndShort + [
            "The kettle clicked off long before the frost had finished leaving the kitchen window this morning."
        ])
        inputs.resurfacingCandidates = inputs.days.flatMap(\.pages)
        let today = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])

        let page = GamePageSourceAdapter().candidates(
            for: today, context: .make(for: today), inputs: inputs, now: now
        ).first
        let offered = page?.payload.metadata.values.joined(separator: " ") ?? ""

        XCTAssertFalse(offered.isEmpty)
        XCTAssertFalse(
            offered.contains("finished leaving the kitchen window this morning"),
            "a long sentence should arrive truncated, not whole"
        )
    }

    /// And the gate is still a gate: a reader with almost nothing kept is not
    /// handed a game made of three phrases.
    func testAThinArchiveStillOpensNoGame() {
        var inputs = BookSourceInputs.empty
        inputs.days = archive(Array(plainAndShort.prefix(3)))
        inputs.resurfacingCandidates = inputs.days.flatMap(\.pages)
        let today = BookDay(id: BookDay.id(for: now, calendar: calendar), date: now, pages: [])

        XCTAssertTrue(GamePageSourceAdapter().candidates(
            for: today, context: .make(for: today), inputs: inputs, now: now
        ).isEmpty)
    }
}
