import XCTest
@testable import InsideCoverCore

final class InkrestOfficeHoursTests: XCTestCase {
    private func localDate(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private func todayWith(pages: [BookPage]) -> BookDay {
        let now = Date()
        return BookDay(
            id: BookDay.id(for: now),
            date: Calendar.current.startOfDay(for: now),
            pages: pages
        )
    }

    private func keptPage() -> BookPage {
        BookPage(
            type: .diary,
            promptText: "Right now",
            userInput: "The kettle finally forgave me.",
            tags: []
        )
    }

    func testWindowOpensBetweenEightAndTen() {
        XCTAssertFalse(InkrestOfficeHours.isOpen(localDate(hour: 19, minute: 59)))
        XCTAssertTrue(InkrestOfficeHours.isOpen(localDate(hour: 20, minute: 0)))
        XCTAssertTrue(InkrestOfficeHours.isOpen(localDate(hour: 21, minute: 59)))
        XCTAssertFalse(InkrestOfficeHours.isOpen(localDate(hour: 22, minute: 0)))
        XCTAssertFalse(InkrestOfficeHours.isOpen(localDate(hour: 9)))
    }

    func testRotatingPromptIsDeterministicPerDay() {
        let day = BookDay(id: "2026-06-10", date: Date(), pages: [])
        let first = InkrestOfficeHours.prompt(for: day)
        let second = InkrestOfficeHours.prompt(for: day)
        XCTAssertEqual(first, second, "same day should choose the same lens")
        XCTAssertFalse(first.question.isEmpty)
        XCTAssertTrue(InkrestOfficeHours.rotatingPrompts.contains(first))
    }

    func testOfficeHoursAllowsASubstantialSitting() {
        XCTAssertEqual(InkrestOfficeHours.replyCap, 7)
    }

    func testPromptRequiresRichSpecificReflectionWithoutStackingQuestions() {
        let intake = InkrestIntake(
            promptID: "values",
            lens: "values",
            rotatingQuestion: "What quietly mattered?",
            rotatingAnswer: "I stayed with a difficult conversation instead of escaping it.",
            innerWeather: "rain clearing",
            freeNote: "I am proud and tired."
        )
        let prompt = InkrestOfficeHoursPromptBuilder.prompt(
            intake: intake,
            day: todayWith(pages: [keptPage()]),
            previousTurns: [],
            userMessage: intake.openingMessage,
            isClosing: false
        )

        XCTAssertTrue(prompt.contains("Write 3 to 5 short paragraphs"))
        XCTAssertTrue(prompt.contains("reflect at least two specific details or tensions"))
        XCTAssertTrue(prompt.contains("ask exactly ONE curious narrative-therapy question"))
        XCTAssertTrue(prompt.contains("Do not rush toward advice"))
    }

    func testClosingPromptSynthesizesTheWholeSitting() {
        let prompt = InkrestOfficeHoursPromptBuilder.prompt(
            intake: InkrestIntake(),
            day: todayWith(pages: [keptPage()]),
            previousTurns: [AskTheBookTurn(prompt: "I kept going.", answer: "That sounds costly and deliberate.")],
            userMessage: "I think I needed someone to notice.",
            isClosing: true
        )

        XCTAssertTrue(prompt.contains("Take 4 to 6 short paragraphs"))
        XCTAssertTrue(prompt.contains("Gather the important thread across the whole sitting"))
        XCTAssertTrue(prompt.contains("reflect back two specific things"))
    }

    func testSurfacesInWindowWithAKeptPage() {
        let adapter = InkrestOfficeHoursPageSourceAdapter()
        let day = todayWith(pages: [keptPage()])
        let now = localDate(hour: 20, minute: 30)
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: .empty, now: now)
        XCTAssertEqual(pages.count, 1)
        let page = try? XCTUnwrap(pages.first)
        XCTAssertEqual(page?.type, .inkrestOfficeHours)
        XCTAssertFalse(page?.payload.metadata["rotatingQuestion"]?.isEmpty ?? true)
        XCTAssertEqual(page?.payload.metadata["rotatingPromptID"], InkrestOfficeHours.prompt(for: day).id)
        XCTAssertTrue(page?.payload.metadata["tags"]?.contains("dr-inkrest") ?? false)
    }

    func testStaysClosedOutsideWindow() {
        let adapter = InkrestOfficeHoursPageSourceAdapter()
        let day = todayWith(pages: [keptPage()])
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: .empty, now: localDate(hour: 14))
        XCTAssertTrue(pages.isEmpty, "Office Hours should only open in the evening")
    }

    func testDoesNotOpenWithoutEvidence() {
        let adapter = InkrestOfficeHoursPageSourceAdapter()
        let day = todayWith(pages: [])
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: .empty, now: localDate(hour: 20, minute: 30))
        XCTAssertTrue(pages.isEmpty, "a blank day with no distress has nothing to sit with yet")
    }

    func testDoesNotRepeatAfterBeingKept() {
        let adapter = InkrestOfficeHoursPageSourceAdapter()
        let now = localDate(hour: 20, minute: 30)
        let slot = BookDay.id(for: now)
        let keptSitting = BookPage(
            type: .inkrestOfficeHours,
            promptText: "Dr. Inkrest's Office Hours",
            userInput: "We sat a while.",
            tags: ["inkrest-office-hours", "inkrest-office-hours:\(slot)"]
        )
        let day = todayWith(pages: [keptPage(), keptSitting])
        let pages = adapter.candidates(for: day, context: CuratorContext.make(for: day), inputs: .empty, now: now)
        XCTAssertTrue(pages.isEmpty, "a kept sitting closes the lamp for the evening")
    }
}
