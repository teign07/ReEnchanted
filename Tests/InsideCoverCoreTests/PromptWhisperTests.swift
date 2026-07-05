import XCTest
@testable import InsideCoverCore

final class PromptWhisperTests: XCTestCase {
    func testPromptsAreDistinctAndDeterministicForFixedDay() {
        let now = Self.date(year: 2026, month: 7, day: 5, hour: 9)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let inputs = BookSourceInputs.empty

        let first = PromptWhisperRegistry.prompts(for: day, inputs: inputs, now: now, count: 3)
        let second = PromptWhisperRegistry.prompts(for: day, inputs: inputs, now: now, count: 3)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(Set(first.map(\.id)).count, 3)
    }

    func testPromptsBlendCheckInsAndMissionsAcrossAWeek() {
        let inputs = BookSourceInputs.empty
        var kinds: Set<PromptWhisper.Kind> = []

        for offset in 0..<7 {
            let now = Calendar.current.date(byAdding: .day, value: offset, to: Self.date(year: 2026, month: 7, day: 5, hour: 9))!
            let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
            kinds.formUnion(PromptWhisperRegistry.prompts(for: day, inputs: inputs, now: now, count: 3).map(\.kind))
        }

        XCTAssertTrue(kinds.contains(.checkIn))
        XCTAssertTrue(kinds.contains(.mission))
    }

    func testPromptWhisperFromMissionMapsFields() {
        let mission = PlayfulMission(
            id: "rough-test",
            title: "Texture Test",
            prompt: "Touch something rough.",
            proofPrompt: "Write the rough thing.",
            tags: ["touch", "texture"],
            allowsPhoto: false
        )

        let whisper = PromptWhisperRegistry.promptWhisper(from: mission)

        XCTAssertEqual(whisper.id, "mission-rough-test")
        XCTAssertEqual(whisper.kind, .mission)
        XCTAssertEqual(whisper.title, mission.title)
        XCTAssertEqual(whisper.body, mission.prompt)
        XCTAssertEqual(whisper.keepPrompt, mission.proofPrompt)
        XCTAssertEqual(whisper.tags, mission.tags)
    }

    func testPromptWhisperKeepBuildsSouvenirPage() {
        let whisper = PromptWhisper(
            id: "checkin-test",
            kind: .checkIn,
            title: "Test",
            body: "What is true?",
            keepPrompt: "What was true?",
            tags: ["truth", "check-in"]
        )
        let now = Self.date(year: 2026, month: 7, day: 5, hour: 11)

        let page = PromptWhisperKeep.page(for: whisper, answer: "  The lamp was on.  ", now: now)

        XCTAssertNotNil(page)
        XCTAssertEqual(page?.type, .souvenir)
        XCTAssertEqual(page?.createdAt, now)
        XCTAssertEqual(page?.promptText, "What was true?")
        XCTAssertEqual(page?.userInput, "The lamp was on.")
        XCTAssertEqual(page?.sourceID, BookPageSourceRegistry.source(for: .souvenir).id)
        XCTAssertEqual(page?.promptVersion, "prompt-whisper-v1")
        XCTAssertTrue(page?.tags.contains("souvenir") == true)
        XCTAssertTrue(page?.tags.contains("prompt-whisper") == true)
        XCTAssertTrue(page?.tags.contains("checkIn") == true)
        XCTAssertTrue(page?.tags.contains("checkin-test") == true)
        XCTAssertTrue(page?.tags.contains("truth") == true)
    }

    func testPromptWhisperKeepRejectsBlankAnswers() {
        let whisper = PromptWhisper(
            id: "checkin-empty",
            kind: .checkIn,
            title: "Test",
            body: "What is true?",
            keepPrompt: "What was true?",
            tags: []
        )

        XCTAssertNil(PromptWhisperKeep.page(for: whisper, answer: " \n\t ", now: Date()))
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
