import XCTest
@testable import InsideCoverCore

final class BindingRevelationsTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int, hour: Int = 20) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: hour))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func page(
        _ input: String,
        dayOffset: Int,
        hour: Int = 20,
        type: BookPageType = .souvenir,
        weather: [String] = [],
        context: Bool = true
    ) -> BookPage {
        let created = day(dayOffset, hour: hour)
        return BookPage(
            id: "page-\(dayOffset)-\(hour)-\(input.prefix(8))",
            type: type,
            createdAt: created,
            promptText: "Prompt",
            userInput: input,
            origin: .userAuthored,
            context: context
                ? BookPageContextSnapshot(at: created, calendar: calendar, weatherTags: weather)
                : nil
        )
    }

    /// A month has to carry some archive before the Book claims to have read it.
    func testThinPeriodsRevealNothing() {
        let pages = [
            page("A short line about the morning.", dayOffset: 0),
            page("Another short line entirely.", dayOffset: 1)
        ]
        XCTAssertTrue(BindingRevelations.find(pages: pages, now: day(3), calendar: calendar).isEmpty)
    }

    /// The headline finding: a word the reader leant on without hearing it.
    func testFindsTheWordTheReaderKeptUsing() {
        var pages: [BookPage] = []
        for offset in 0..<6 {
            pages.append(page("The harbour was quiet again this evening, harbour light on everything.", dayOffset: offset))
        }
        pages.append(page("Completely different subject matter today, nothing related.", dayOffset: 7))

        let found = BindingRevelations.find(pages: pages, now: day(9), calendar: calendar)
        guard let word = found.first(where: { $0.kind == .recurringWord }) else {
            return XCTFail("expected a recurring-word revelation, got \(found.map(\.kind))")
        }
        XCTAssertTrue(word.title.contains("harbour"), word.title)
        // Two-sided honesty: the claim must carry its base rate, not just its hits.
        XCTAssertTrue(word.body.contains("written days"), word.body)
        XCTAssertFalse(word.evidence.isEmpty)
    }

    /// Repetition inside a single day is an afternoon, not a habit.
    func testOneEnthusiasticDayIsNotRecurrence() {
        let pages = (0..<8).map { index in
            page("Lighthouse lighthouse lighthouse in the fog.", dayOffset: 0, hour: 8 + index)
        } + [
            page("A separate thought on another day entirely.", dayOffset: 4),
            page("And one more, different again, later on.", dayOffset: 5),
            page("Something else worth keeping here too.", dayOffset: 6)
        ]
        let found = BindingRevelations.find(pages: pages, now: day(8), calendar: calendar)
        XCTAssertFalse(
            found.contains { $0.kind == .recurringWord && $0.title.contains("lighthouse") },
            "one day of repetition should not read as a refrain"
        )
    }

    /// The echo: nearly the same thought, weeks apart, forgotten in between.
    func testFindsTheSameThoughtWrittenTwice() {
        let sentence = "I keep wondering whether leaving the harbour town was actually the right decision"
        var pages = [
            page(sentence, dayOffset: 0),
            page("An unrelated note about breakfast and the bus.", dayOffset: 3),
            page("Another unrelated note, this time about paperwork.", dayOffset: 6),
            page(sentence + " really", dayOffset: 20)
        ]
        pages.append(page("One more filler line to clear the day floor.", dayOffset: 9))

        let found = BindingRevelations.find(pages: pages, now: day(22), calendar: calendar)
        guard let echo = found.first(where: { $0.kind == .saidItTwice }) else {
            return XCTFail("expected an echo revelation, got \(found.map(\.kind))")
        }
        XCTAssertTrue(echo.title.contains("20 days apart"), echo.title)
        XCTAssertEqual(echo.evidence.count, 2)
    }

    /// Consecutive nights on one subject are a mood; the Book stays quiet.
    func testAdjacentRepetitionIsNotAnEcho() {
        let sentence = "The same weary thought about the same unfinished project again"
        let pages = [
            page(sentence, dayOffset: 0),
            page(sentence, dayOffset: 1),
            page("Something quite different for a change.", dayOffset: 2),
            page("And another separate line to reach the floor.", dayOffset: 3),
            page("A fifth line, unrelated to any of it.", dayOffset: 4)
        ]
        let found = BindingRevelations.find(pages: pages, now: day(6), calendar: calendar)
        XCTAssertFalse(found.contains { $0.kind == .saidItTwice })
    }

    /// A gap is not a failure. It is a thing that happened, and returning from
    /// it is the part worth binding.
    func testFindsTheReturnAfterSilence() {
        let pages = [
            page("Early in the month, writing most days.", dayOffset: 0),
            page("Still here, still writing things down.", dayOffset: 1),
            page("A third entry before everything stopped.", dayOffset: 2),
            page("Back again after a long time away from this.", dayOffset: 14),
            page("And writing once more the following day.", dayOffset: 15)
        ]
        let found = BindingRevelations.find(pages: pages, now: day(17), calendar: calendar)
        guard let silence = found.first(where: { $0.kind == .returnAfterSilence }) else {
            return XCTFail("expected a silence revelation, got \(found.map(\.kind))")
        }
        XCTAssertTrue(silence.title.contains("12 days"), silence.title)
        // The evidence is the return, not the absence.
        XCTAssertEqual(silence.evidence.first?.date, day(14))
    }

    /// Same archive in, same reading out — a re-bound month must not reshuffle.
    func testFindingsAreDeterministic() {
        var pages: [BookPage] = []
        for offset in 0..<10 {
            pages.append(page("Rain against the window again, rain all week.", dayOffset: offset, weather: ["rain"]))
        }
        let first = BindingRevelations.find(pages: pages, now: day(12), calendar: calendar)
        let second = BindingRevelations.find(pages: pages.reversed(), now: day(12), calendar: calendar)
        XCTAssertEqual(first, second)
    }

    /// Weather claims need a real sample behind them and must report the base
    /// rate they were drawn from.
    func testWeatherToneClaimCarriesItsBaseRate() {
        var pages: [BookPage] = []
        for offset in 0..<6 {
            pages.append(page("A tired, heavy, lonely sort of day and I am worn out.", dayOffset: offset, weather: ["rain"]))
        }
        for offset in 6..<10 {
            pages.append(page("Bright and glad and laughing about nothing much.", dayOffset: offset, weather: ["clear"]))
        }
        let found = BindingRevelations.find(pages: pages, now: day(12), calendar: calendar, limit: 8)
        if let weather = found.first(where: { $0.kind == .weatherAndInk }) {
            XCTAssertTrue(weather.body.contains("You wrote"), weather.body)
            XCTAssertFalse(weather.evidence.isEmpty)
        }
    }

    /// Ordering is strongest-first and stable, so the foreword and the closing
    /// can rely on `.first` and `.dropFirst().first` meaning something.
    func testFindingsAreOrderedStrongestFirst() {
        var pages: [BookPage] = []
        for offset in 0..<12 {
            pages.append(page("The harbour again, harbour weather, harbour light.", dayOffset: offset))
        }
        let found = BindingRevelations.find(pages: pages, now: day(14), calendar: calendar, limit: 6)
        XCTAssertEqual(found, found.sorted { left, right in
            if left.strength == right.strength { return left.id < right.id }
            return left.strength > right.strength
        })
    }
}
