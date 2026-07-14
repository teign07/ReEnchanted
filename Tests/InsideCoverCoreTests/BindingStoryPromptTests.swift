import XCTest
@testable import InsideCoverCore

final class BindingStoryPromptTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var monthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9))!
    }

    private func date(day: Int, hour: Int = 22) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func braid(day: Int, title: String, scene: String, kept: String) -> BookPage {
        BraidPageDetails.annotated(
            BookPage(
                id: "braid-\(day)-\(title)",
                type: .bookOfYou,
                createdAt: date(day: day),
                promptText: "Book of You",
                userInput: """
                \(title)

                \(scene)

                The Book kept the page: \(kept).
                """,
                tags: ["braid"]
            ),
            context: .empty
        )
    }

    private func issue(pages: [BookPage]) -> WeeklyIssue {
        WeeklyIssue(
            number: 3,
            startDate: date(day: 1, hour: 0),
            endDate: date(day: 8, hour: 0),
            dateRange: "Jul 1–7",
            keptCount: pages.count,
            highlights: [],
            pages: pages
        )
    }

    private func edition(pages: [BookPage]) -> MonthlyEdition {
        let days = Dictionary(grouping: pages) { calendar.startOfDay(for: $0.createdAt) }
            .map { day, pages in
                BookDay(id: BookDay.id(for: day, calendar: calendar), date: day, pages: pages)
            }
        return MonthlyEditionBuilder.edition(
            from: days,
            readerName: "Reader",
            startDate: monthStart,
            endDate: date(day: 31, hour: 23),
            generatedAt: date(day: 31, hour: 23),
            calendar: calendar
        )
    }

    func testWeeklyStoryPromptReadsEveryDailyBindingInChronologicalOrder() throws {
        let late = braid(day: 7, title: "The Open Door", scene: "The latch finally lifted.", kept: "an opening can stay quiet")
        let early = braid(day: 1, title: "Rain at the Glass", scene: "Rain found the kitchen window.", kept: "the first knock mattered")
        let middle = braid(day: 4, title: "A Lamp Between", scene: "The lamp held against the dim room.", kept: "small light was still light")
        let unrelated = BookPage(
            type: .fuel,
            createdAt: date(day: 2),
            promptText: "Fuel",
            userInput: "SENTINEL RAW FUEL MUST NOT REACH GEMMA"
        )

        let spec = try XCTUnwrap(BindingStoryPromptBuilder.weekly(for: issue(pages: [late, unrelated, middle, early]), calendar: calendar))
        let prompt = spec.prompt

        let earlyIndex = try XCTUnwrap(prompt.range(of: "Rain at the Glass")?.lowerBound)
        let middleIndex = try XCTUnwrap(prompt.range(of: "A Lamp Between")?.lowerBound)
        let lateIndex = try XCTUnwrap(prompt.range(of: "The Open Door")?.lowerBound)
        XCTAssertLessThan(earlyIndex, middleIndex)
        XCTAssertLessThan(middleIndex, lateIndex)
        XCTAssertTrue(prompt.contains("2026-07-01"))
        XCTAssertTrue(prompt.contains("2026-07-07"))
        XCTAssertFalse(prompt.contains("SENTINEL RAW FUEL"))
        XCTAssertTrue(prompt.contains("binding of bindings"))
        XCTAssertTrue(prompt.contains("one continuous story"))
        XCTAssertTrue(prompt.contains("do not produce a day-by-day recap"))
        XCTAssertTrue(prompt.contains("Do not invent events"))
        XCTAssertEqual(spec.sourceID, "weekly-binding-story")
    }

    func testMonthlyStoryPromptRepresentsAllThirtyOneBindingsWithinLocalBudget() throws {
        let pages = (1...31).map { day in
            braid(
                day: day,
                title: String(format: "Night %02d", day),
                scene: String(repeating: "A distinct long scene kept returning to the window and changing its light. ", count: 12),
                kept: "night \(day) left its own unmistakable stitch in the month"
            )
        }
        let spec = try XCTUnwrap(BindingStoryPromptBuilder.monthly(for: edition(pages: pages), calendar: calendar))

        for day in 1...31 {
            XCTAssertTrue(spec.prompt.contains(String(format: "Night %02d", day)), "missing day \(day)")
        }
        let first = try XCTUnwrap(spec.prompt.range(of: "Night 01")?.lowerBound)
        let last = try XCTUnwrap(spec.prompt.range(of: "Night 31")?.lowerBound)
        XCTAssertLessThan(first, last)
        XCTAssertLessThan(spec.prompt.count, 12_000, "month prompt must leave room in Gemma's 4,096-token context window")
        XCTAssertEqual(spec.sourceID, "monthly-binding-story")
        XCTAssertGreaterThan(spec.maxTokens, BindingStoryPromptBuilder.weekly(for: issue(pages: [pages[0]]), calendar: calendar)!.maxTokens)
    }

    func testStoryGenerationIsSkippedWithoutDailyBookOfYouBindings() {
        let souvenir = BookPage(
            type: .souvenir,
            createdAt: date(day: 1),
            promptText: "Souvenir",
            userInput: "A real kept page, but not a nightly binding."
        )

        XCTAssertNil(BindingStoryPromptBuilder.weekly(for: issue(pages: [souvenir]), calendar: calendar))
        XCTAssertNil(BindingStoryPromptBuilder.monthly(for: edition(pages: [souvenir]), calendar: calendar))
    }

    func testBindingStoriesSurviveCodableRoundTrips() throws {
        var weekly = issue(pages: [braid(day: 1, title: "First Thread", scene: "A thread appeared.", kept: "it held")])
        weekly.bindingStory = "The week became one piece of cloth."
        let decodedWeekly = try JSONDecoder().decode(WeeklyIssue.self, from: JSONEncoder().encode(weekly))
        XCTAssertEqual(decodedWeekly.bindingStory, weekly.bindingStory)

        var monthly = edition(pages: [braid(day: 1, title: "First Thread", scene: "A thread appeared.", kept: "it held")])
        monthly.bindingStory = "The month learned what the thread connected."
        let decodedMonthly = try JSONDecoder().decode(MonthlyEdition.self, from: JSONEncoder().encode(monthly))
        XCTAssertEqual(decodedMonthly.bindingStory, monthly.bindingStory)
    }
}
