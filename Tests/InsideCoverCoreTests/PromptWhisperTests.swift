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
        XCTAssertEqual(whisper.allowsPhoto, false)
    }

    func testPromptWhisperSnapshotRoundTripsForColdLaunch() throws {
        let whisper = PromptWhisper(
            id: "mission-cold-launch",
            kind: .mission,
            title: "Cold Launch Mission",
            body: "Find the first glint after the Book opens.",
            keepPrompt: "Keep the glint.",
            tags: ["light", "notification"],
            allowsPhoto: true
        )

        let decoded = try JSONDecoder().decode(
            PromptWhisper.self,
            from: JSONEncoder().encode(whisper)
        )

        XCTAssertEqual(decoded, whisper)
    }

    func testTappedMissionBuildsExactStandaloneMissionWithoutRerolling() throws {
        let now = Self.date(year: 2026, month: 7, day: 5, hour: 11)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let whisper = PromptWhisper(
            id: "mission-notification-only",
            kind: .mission,
            title: "The Notification's Mission",
            body: "Find the one blue thing the room nearly hid.",
            keepPrompt: "Write what the blue thing was guarding.",
            tags: ["blue", "visual"],
            allowsPhoto: true
        )

        let surface = WonderCompassPageSourceAdapter().promptWhisperSurface(
            for: whisper,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(surface.sourceID, BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID)
        XCTAssertEqual(surface.payload.metadata["playfulMissionID"], "notification-only")
        XCTAssertEqual(surface.payload.metadata["playfulMissionTitle"], whisper.title)
        XCTAssertEqual(surface.payload.metadata["mission"], whisper.body)
        XCTAssertEqual(surface.payload.metadata["souvenirPrompt"], whisper.keepPrompt)
        XCTAssertEqual(surface.payload.metadata["proofKind"], "sentence-or-photo")
        XCTAssertEqual(surface.payload.metadata["openedFromPromptWhisper"], "true")
        XCTAssertEqual(surface.payload.metadata["promptWhisperID"], whisper.id)
    }

    func testTappedMindfulnessCheckInBuildsKeepableSouvenirPage() {
        let now = Self.date(year: 2026, month: 7, day: 5, hour: 11)
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let whisper = PromptWhisper(
            id: "checkin-nearest-color",
            kind: .checkIn,
            title: "Color census",
            body: "What color is nearest your left hand?",
            keepPrompt: "What color was closest?",
            tags: ["color", "visual"]
        )

        let surface = WonderCompassPageSourceAdapter().promptWhisperSurface(
            for: whisper,
            day: day,
            context: CuratorContext.make(for: day),
            inputs: .empty,
            now: now
        )

        XCTAssertEqual(surface.type, .souvenir)
        XCTAssertEqual(surface.intent, .capture)
        XCTAssertEqual(surface.prompt, whisper.title)
        XCTAssertEqual(surface.detail, whisper.body)
        XCTAssertEqual(surface.payload.metadata["placeholder"], whisper.keepPrompt)
        XCTAssertEqual(surface.payload.metadata["openedFromPromptWhisper"], "true")
        XCTAssertEqual(surface.payload.metadata["promptWhisperID"], whisper.id)
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
