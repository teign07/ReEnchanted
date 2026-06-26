import XCTest
@testable import InsideCoverCore

final class StoryPageLocationTests: XCTestCase {
    func testNewLocationRoomsAreNarrativeLocationsWithBundledAssets() {
        let entitiesByID = Dictionary(uniqueKeysWithValues: NarrativePackRegistry.entities.map { ($0.id, $0) })
        let expected: [(id: String, asset: String)] = [
            ("location-quillquarium", "LabyrinthLocationQuillquarium"),
            ("location-book-burrow", "LabyrinthLocationBookBurrow"),
            ("location-dorm", "LabyrinthLocationDorm")
        ]

        for item in expected {
            let entity = entitiesByID[item.id]
            XCTAssertEqual(entity?.kind, .location)
            XCTAssertTrue(entity?.tags.contains("story-setting") == true)
            XCTAssertTrue(BookReferenceCatalog.bundledCharacterIllustrationAssetNames.contains(item.asset))
        }
    }

    func testStoryPagePacketCarriesLocationSettingSeparateFromCast() throws {
        let now = makeDate()
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        let inputs = BookSourceInputs.empty

        let packet = StoryScenePacketBuilder.packet(for: day, inputs: inputs, now: now)
        let location = try XCTUnwrap(packet.selectedEntities.first { $0.kind == .location })

        XCTAssertTrue(packet.selectedEntities.contains { $0.kind == .character })
        XCTAssertTrue(location.tags.contains("story-setting"))
    }

    func testStoryPageDraftCandidateWritesSettingMetadata() throws {
        let now = makeDate()
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])

        let surface = NarrativeOSPageSourceAdapter.draftCandidate(for: day, inputs: .empty, now: now)

        let settingID = try XCTUnwrap(surface.payload.metadata["storySettingID"]?.nonEmpty)
        let settingName = try XCTUnwrap(surface.payload.metadata["storySettingName"]?.nonEmpty)
        let settingDetail = try XCTUnwrap(surface.payload.metadata["storySettingDetail"]?.nonEmpty)
        let selectedEntityIDs = try XCTUnwrap(surface.payload.metadata["selectedEntityIDs"])

        XCTAssertTrue(settingID.hasPrefix("location-"))
        XCTAssertFalse(settingName.isEmpty)
        XCTAssertTrue(settingDetail.contains("Scene job:"))
        XCTAssertTrue(selectedEntityIDs.split(separator: ",").map(String.init).contains(settingID))
    }

    func testStoryPageSettingRespondsToLocationBeliefOffsets() throws {
        let now = makeDate()
        let day = BookDay(id: BookDay.id(for: now), date: Calendar.current.startOfDay(for: now), pages: [])
        var inputs = BookSourceInputs.empty
        inputs.entityBeliefOffsets = ["location-kitchens": 80]

        let surface = NarrativeOSPageSourceAdapter.draftCandidate(for: day, inputs: inputs, now: now)

        XCTAssertEqual(surface.payload.metadata["storySettingID"], "location-kitchens")
        XCTAssertEqual(surface.payload.metadata["storySettingName"], "The Kitchens")
    }

    private func makeDate() -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 26,
            hour: 15
        ).date!
    }
}
