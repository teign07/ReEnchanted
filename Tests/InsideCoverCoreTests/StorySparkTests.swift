import XCTest
@testable import InsideCoverCore

final class StorySparkTests: XCTestCase {
    func testStorySparkCandidatePrefersStrongRecentSouvenirAndSkipsUsedSource() {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 14)
        let spark = strongSouvenir(createdAt: Self.date(year: 2026, month: 6, day: 12, hour: 9))
        let weak = BookPage(
            id: "weak-souvenir",
            type: .souvenir,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: 10),
            promptText: "Catch one bright particular.",
            userInput: "It was fine.",
            tags: ["souvenir"]
        )
        let day = BookDay(id: "2026-06-12", date: Self.date(year: 2026, month: 6, day: 12, hour: 0), pages: [weak, spark])

        XCTAssertEqual(StorySpark.candidate(for: day, inputs: .empty, now: now)?.id, "rain-page")

        let usedStoryPage = BookPage(
            id: "used-story-spark",
            type: .narrativeOS,
            createdAt: Self.date(year: 2026, month: 6, day: 12, hour: 11),
            promptText: "Let this sentence open a door?",
            userInput: "Chosen path: Slice of Life",
            tags: ["narrative-os", "story-spark", "story-spark-source:rain-page"]
        )
        let usedDay = BookDay(id: day.id, date: day.date, pages: [weak, spark, usedStoryPage])

        XCTAssertNil(StorySpark.candidate(for: usedDay, inputs: .empty, now: now))
    }

    func testStorySparkPacketUsesSouvenirDoorRecipe() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 14)
        let day = dayWithStrongSouvenir()

        let packet = StoryScenePacketBuilder.packet(for: day, inputs: .empty, now: now)
        let blueprint = try XCTUnwrap(packet.blueprint)

        XCTAssertEqual(packet.title, "Story Spark: A Sentence Opens")
        XCTAssertEqual(blueprint.recipeID, "souvenir-door")
        XCTAssertEqual(blueprint.grounding.kind, .souvenirDoor)
        XCTAssertEqual(blueprint.grounding.sourceID, "rain-page")
        XCTAssertTrue(blueprint.grounding.text.contains("parking lot look like a page under glass"))
    }

    func testStorySparkSurfaceCarriesSourceMetadataAndTags() throws {
        let now = Self.date(year: 2026, month: 6, day: 12, hour: 14)
        let surface = NarrativeOSPageSourceAdapter.draftCandidate(
            for: dayWithStrongSouvenir(),
            inputs: .empty,
            now: now
        )
        let metadata = surface.payload.metadata
        let tags = Set((metadata["tags"] ?? "").split(separator: ",").map(String.init))

        XCTAssertEqual(surface.prompt, "Want this little sentence to open a door?")
        XCTAssertEqual(surface.payload.headline, "Story Spark: A Sentence Opens")
        XCTAssertEqual(metadata["storyRecipeID"], "souvenir-door")
        XCTAssertEqual(metadata["storyRecipeGroundingKind"], StoryGroundingKind.souvenirDoor.rawValue)
        XCTAssertEqual(metadata["storySparkSourcePageID"], "rain-page")
        XCTAssertEqual(metadata["storySparkSentence"], "The rain made the parking lot look like a page under glass.")
        XCTAssertTrue(tags.contains("story-spark"))
        XCTAssertTrue(tags.contains("story-spark-source:rain-page"))
        XCTAssertTrue(tags.contains("story-spark-recipe"))
    }

    private func dayWithStrongSouvenir() -> BookDay {
        BookDay(
            id: "2026-06-12",
            date: Self.date(year: 2026, month: 6, day: 12, hour: 0),
            pages: [strongSouvenir(createdAt: Self.date(year: 2026, month: 6, day: 12, hour: 9))]
        )
    }

    private func strongSouvenir(createdAt: Date) -> BookPage {
        BookPage(
            id: "rain-page",
            type: .souvenir,
            createdAt: createdAt,
            promptText: "Catch one bright particular.",
            userInput: "The rain made the parking lot look like a page under glass.",
            tags: ["souvenir"]
        )
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/New_York")
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
