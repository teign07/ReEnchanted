import XCTest
@testable import InsideCoverCore

final class EchoesAndRipplesTests: XCTestCase {

    // MARK: KeepEcho

    func testEchoNamesOldSharedRareWord() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(
            id: "old",
            createdAt: now.addingTimeInterval(-40 * 86_400),
            input: "The lighthouse blinked all night over the water."
        )
        let days = [dayHolding([old])]
        let echo = try XCTUnwrap(
            KeepEcho.find(for: "A lighthouse again, further down the coast.", pageID: "new", in: days, now: now)
        )
        XCTAssertEqual(echo.sharedWord, "lighthouse")
        XCTAssertEqual(echo.sourcePageID, "old")
        XCTAssertTrue(echo.line.contains("lighthouse"))
    }

    func testEchoIgnoresRecentPagesAndPrivateLogs() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let recent = prosePage(
            id: "recent",
            createdAt: now.addingTimeInterval(-3 * 86_400),
            input: "The lighthouse blinked all night over the water."
        )
        XCTAssertNil(
            KeepEcho.find(for: "A lighthouse again tonight.", pageID: "new", in: [dayHolding([recent])], now: now),
            "A 3-day-old page is too recent to echo."
        )

        let oldBody = BookPage(
            id: "body",
            type: .body,
            createdAt: now.addingTimeInterval(-40 * 86_400),
            promptText: "How does the body read today?",
            userInput: "The lighthouse of a headache all afternoon.",
            tags: ["body"]
        )
        XCTAssertNil(
            KeepEcho.find(for: "A lighthouse again tonight.", pageID: "new", in: [dayHolding([oldBody])], now: now),
            "Body logs never echo."
        )
    }

    func testEchoIsNilWithoutSharedWord() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(
            id: "old",
            createdAt: now.addingTimeInterval(-40 * 86_400),
            input: "The kettle sang twice before I noticed."
        )
        XCTAssertNil(
            KeepEcho.find(for: "A completely unrelated harbor sentence.", pageID: "new", in: [dayHolding([old])], now: now)
        )
    }

    func testEchoIsDeterministic() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 12)
        let old = prosePage(
            id: "old",
            createdAt: now.addingTimeInterval(-40 * 86_400),
            input: "The lighthouse blinked all night over the water."
        )
        let days = [dayHolding([old])]
        let first = KeepEcho.find(for: "A lighthouse again.", pageID: "new", in: days, now: now)
        let second = KeepEcho.find(for: "A lighthouse again.", pageID: "new", in: days, now: now)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    // MARK: Belief-weighted voices

    func testHeavyBeliefVoiceDominatesSelection() {
        let heavy = "professor-thaddeus-mook"
        var beliefs = Dictionary(uniqueKeysWithValues: KeepMarginalia.voices.map { ($0.slug, 1) })
        beliefs[heavy] = 500

        var heavyHits = 0
        for index in 0..<40 {
            let note = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "weighted-\(index)",
                beliefBySlug: beliefs
            )
            if note?.castSlug == heavy { heavyHits += 1 }
        }
        XCTAssertGreaterThanOrEqual(heavyHits, 30, "A 500:1 weighting should dominate.")
    }

    func testEmptyBeliefMapMatchesDefaultWeighting() {
        // With no beliefs supplied every voice weighs the base glow of 20, an
        // even split — the same voice a bare call would pick.
        for index in 0..<12 {
            let withEmpty = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "even-\(index)",
                beliefBySlug: [:]
            )
            let flat = Dictionary(uniqueKeysWithValues: KeepMarginalia.voices.map { ($0.slug, 20) })
            let withFlat = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "even-\(index)",
                beliefBySlug: flat
            )
            XCTAssertEqual(withEmpty?.castSlug, withFlat?.castSlug)
        }
    }

    func testBeliefWeightingStillAppliesInsideGreeterPool() {
        let heavy = "penny-blackletter"
        var beliefs = Dictionary(uniqueKeysWithValues: KeepMarginalia.voices.map { ($0.slug, 1) })
        beliefs[heavy] = 500

        var heavyHits = 0
        for index in 0..<40 {
            let note = KeepMarginalia.note(
                for: "A small true thing happened by the window today.",
                pageType: .diary,
                pageID: "greeter-weighted-\(index)",
                beliefBySlug: beliefs,
                priorKeepCount: 5
            )
            XCTAssertTrue(KeepMarginalia.greeterSlugs.contains(note?.castSlug ?? ""))
            if note?.castSlug == heavy { heavyHits += 1 }
        }
        XCTAssertGreaterThanOrEqual(heavyHits, 30, "Belief weighting still dominates within the greeter pool.")
    }

    // MARK: Festival notes

    func testFestivalNoteHasPerSabbatLines() {
        let sabbats = ["imbolc", "ostara", "beltane", "litha", "lughnasadh", "mabon", "samhain", "yule"]
        var lines: Set<String> = []
        for id in sabbats {
            let note = KeepMarginalia.festivalNote(celebrationID: id, commonName: id.capitalized)
            lines.insert(note.line)
            XCTAssertTrue(note.castName.contains(id.capitalized))
        }
        XCTAssertEqual(lines.count, sabbats.count, "Each sabbat gets a distinct line.")

        let unknown = KeepMarginalia.festivalNote(celebrationID: "full-moon", commonName: "Full Moon")
        XCTAssertTrue(unknown.line.contains("Almanac"))
    }

    // MARK: Belief ripple

    func testRippleTiersByBelief() {
        XCTAssertTrue(BeliefRipple.line(entityName: "Mook", effectiveBelief: 10).contains("stirred"))
        XCTAssertTrue(BeliefRipple.line(entityName: "Mook", effectiveBelief: 45).contains("brightened"))
        XCTAssertTrue(BeliefRipple.line(entityName: "Mook", effectiveBelief: 75).contains("steadier"))
    }

    func testNoteEqualityIncludesRippleLine() {
        let base = KeepMarginalia.Note(castSlug: "x", castName: "X", assetName: "A", line: "L")
        var rippled = base
        rippled.rippleLine = "glow stirred"
        XCTAssertNotEqual(base, rippled)
    }

    // MARK: Fixtures

    // Each page gets a day whose id matches its own date, so `capturedPages`
    // (which windows on `Calendar.current` from the day id) includes it.
    private func dayHolding(_ pages: [BookPage]) -> BookDay {
        let anchor = pages.first?.createdAt ?? Date()
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: anchor)
        let id = String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
        return BookDay(id: id, date: Calendar.current.startOfDay(for: anchor), pages: pages)
    }

    private func prosePage(id: String, createdAt: Date, input: String) -> BookPage {
        BookPage(
            id: id,
            type: .souvenir,
            createdAt: createdAt,
            promptText: "Catch one bright particular.",
            userInput: input,
            tags: ["souvenir"],
            origin: .userAuthored
        )
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
}
