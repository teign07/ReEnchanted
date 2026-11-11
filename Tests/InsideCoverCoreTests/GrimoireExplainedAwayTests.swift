import XCTest
@testable import InsideCoverCore

/// bj, 2026-11-10: "the noticings are super boring … the most boring shit is
/// being surfaced." The rules a Book had actually spoken were the Page
/// explaining itself: afternoon at home bringing the word "afternoon", a blend
/// "discovering" its own ingredient, and drink words arriving with the Page
/// that asks what you drank. None of these may ever become a claim.
final class GrimoireExplainedAwayTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private func day(_ index: Int, pages: [BookPage]) -> BookDay {
        let date = GrimoireDay.date(for: index, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return BookDay(
            id: String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1),
            date: calendar.startOfDay(for: date),
            pages: pages
        )
    }

    private func page(
        _ id: String, day index: Int, hour: Int = 9, type: BookPageType = .diary,
        text: String, weather: [String] = [], place: String? = nil
    ) -> BookPage {
        let start = GrimoireDay.date(for: index, calendar: calendar)
        let at = calendar.date(byAdding: .hour, value: hour, to: start) ?? start
        return BookPage(
            id: id, type: type, createdAt: at,
            promptText: "Prompt", userInput: text, tags: [], origin: .userAuthored,
            context: BookPageContextSnapshot(
                at: at, calendar: calendar, weatherTags: weather,
                nearbyAnchorID: place, locationLabel: place
            )
        )
    }

    private func swept(_ days: [BookDay]) -> GrimoireLedger {
        var ledger = GrimoireLedger()
        ledger.ingest(GrimoireProjection.observations(from: GrimoireSlice(days: days, calendar: calendar)))
        var passes = 0
        while true {
            let report = ledger.sweep(now: GrimoireDay.date(for: 61, calendar: calendar), budget: 900, calendar: calendar)
            passes += 1
            if report.finished || passes > 80 { break }
        }
        return ledger
    }

    private func ref(_ id: String, _ domain: String) -> LoomFeatureRef {
        LoomFeatureRef(id: id, domain: domain, label: id, conditionClause: id, outcomeClause: id)
    }

    // MARK: Through the real projection

    func testAPageKindNeverExplainsTheWordsWrittenOnIt() {
        // Every third day the reader keeps a Fuel Page and writes "seltzer"
        // on it. Other days are diary Pages about something else entirely.
        let days = (0..<60).map { index -> BookDay in
            index % 3 == 0
                ? day(index, pages: [page("fuel-\(index)", day: index, type: .fuel, text: "Seltzer with lime and some toast.")])
                : day(index, pages: [page("diary-\(index)", day: index, text: "Walked the long way past the allotments.")])
        }
        let ledger = swept(days)
        let tautologies = ledger.rows.values.filter { row in
            row.conditionID == "word:seltzer" && row.outcomeID == "kept:\(BookPageType.fuel.rawValue)"
        }
        XCTAssertTrue(tautologies.isEmpty, "the Fuel Page's own answer became a rule about the reader")
    }

    func testAWordNeverEchoesTheWeatherItWasWrittenIn() {
        let days = (0..<60).map { index -> BookDay in
            index % 3 == 0
                ? day(index, pages: [page("p\(index)", day: index, text: "A clear cold sky over the roofs.", weather: ["clear"])])
                : day(index, pages: [page("p\(index)", day: index, text: "Grey and close; stayed inside with tea.", weather: ["cloud"])])
        }
        let ledger = swept(days)
        XCTAssertFalse(
            ledger.rows.values.contains { $0.conditionID == "weather:clear" && $0.outcomeID == "word:clear" },
            "clear weather 'discovered' the word clear"
        )
    }

    func testFunctionWordsNeverEnterTheLedger() {
        let days = (0..<30).map { index in
            day(index, pages: [page("p\(index)", day: index, text: "Over and down, all of it kept off the table.")])
        }
        let ledger = swept(days)
        for word in ["over", "down", "all", "kept", "off"] {
            XCTAssertNil(ledger.featureIDs.firstIndex(of: "word:\(word)"), "“\(word)” is grammar, not a subject")
        }
    }

    // MARK: The rules themselves

    func testABlendCannotDiscoverItsOwnIngredientOrItsFamily() {
        let home = ref("place:home", "place")
        let afternoon = ref("hour:afternoon", "hour")
        let work = ref("place:work", "place")
        let blend = ref("blend:hour:afternoon+place:home", "contextBlend")
        let lookup: (String) -> LoomFeatureRef? = { ["place:home": home, "hour:afternoon": afternoon][$0] }
        XCTAssertTrue(GrimoireInterest.isExplainedAway(shape: .conditional, condition: blend, outcome: home, ref: lookup))
        XCTAssertTrue(GrimoireInterest.isExplainedAway(shape: .conditional, condition: blend, outcome: work, ref: lookup))
        XCTAssertTrue(GrimoireInterest.isExplainedAway(
            shape: .conditional, condition: blend, outcome: ref("word:afternoon", "word"), ref: lookup
        ))
        XCTAssertFalse(GrimoireInterest.isExplainedAway(
            shape: .conditional, condition: blend, outcome: ref("sleep:short", "sleep"), ref: lookup
        ))
    }

    func testAcrossDaysAPageKindIsARealReach() {
        // The same pair on the same Page is the prompt answered; a Fuel Page
        // *followed* by something days later is not.
        let word = ref("word:seltzer", "word")
        let fuel = ref("kept:fuel", "pageKind")
        XCTAssertTrue(GrimoireInterest.isExplainedAway(shape: .conditional, condition: word, outcome: fuel, ref: { _ in nil }))
        XCTAssertFalse(GrimoireInterest.isExplainedAway(shape: .sequential, condition: word, outcome: fuel, ref: { _ in nil }))
    }

    func testAPageAboutTheWeatherIsNotFoundInTheWeather() {
        // "Clear … because the weather page showed clear": the Book writes a
        // weather Page when the sky does something, then credits the reader.
        let clear = ref("weather:clear", "weather")
        let afternoon = ref("hour:afternoon", "hour")
        let blend = ref("blend:hour:afternoon+weather:clear", "contextBlend")
        let lookup: (String) -> LoomFeatureRef? = { ["weather:clear": clear, "hour:afternoon": afternoon][$0] }
        for about in [ref("modality:weather", "modality"), ref("kept:weather", "pageKind")] {
            XCTAssertTrue(GrimoireInterest.isExplainedAway(shape: .conditional, condition: clear, outcome: about, ref: lookup))
            XCTAssertTrue(GrimoireInterest.isExplainedAway(shape: .conditional, condition: blend, outcome: about, ref: lookup))
        }
        // A photo in clear weather is the reader's doing, not the Book's.
        XCTAssertFalse(GrimoireInterest.isExplainedAway(
            shape: .conditional, condition: clear, outcome: ref("media:photograph", "media"), ref: lookup
        ))
    }

    func testAPlaceholderPlaceIsNowhere() {
        var context = BookPageContextSnapshot(at: GrimoireDay.date(for: 3, calendar: calendar), calendar: calendar)
        context.locationLabel = "Current place"
        XCTAssertFalse(WorldConditionsProjector.features(for: context).contains { $0.domain == "place" })
    }

    func testRichCrossingsOutrankWordsAtTheSameStrength() {
        let moon = ref("moon:full", "moon")
        let sleep = ref("sleep:short", "sleep")
        let place = ref("place:harbour", "place")
        let word = ref("word:lantern", "word")
        XCTAssertGreaterThan(
            GrimoireInterest.reach(condition: moon, outcome: sleep),
            GrimoireInterest.reach(condition: place, outcome: word)
        )
    }
}
