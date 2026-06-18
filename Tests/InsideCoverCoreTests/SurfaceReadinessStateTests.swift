import XCTest
@testable import InsideCoverCore

final class SurfaceReadinessStateTests: XCTestCase {
    func testBookOfYouAlwaysNeedsLocalBrainToOpen() {
        XCTAssertTrue(SurfaceReadinessState(type: .bookOfYou).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .bookOfYou, metadata: ["anything": "ready"]).needsLocalBrainToOpen)
    }

    func testIlluminatedPhotoNeedsLocalBrainUntilRenderedPreviewExists() {
        XCTAssertTrue(SurfaceReadinessState(type: .illuminatedPhoto).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .illuminatedPhoto, metadata: ["renderedPreviewPath": ""]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .illuminatedPhoto, metadata: ["renderedPreviewPath": "/tmp/page.png"]).needsLocalBrainToOpen)
    }

    func testNarrativePageNeedsLocalBrainUntilStorySceneExists() {
        XCTAssertTrue(SurfaceReadinessState(type: .narrativeOS).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .narrativeOS, metadata: ["storyScene": ""]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .narrativeOS, metadata: ["storyScene": "The page has dried."]).needsLocalBrainToOpen)
    }

    func testBookFaePageNeedsLocalBrainUntilBespokeSceneExists() {
        XCTAssertTrue(SurfaceReadinessState(type: .bookFae).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .bookFae, metadata: ["storyScene": ""]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .bookFae, metadata: ["storyScene": "A thorn taps twice against the margin."]).needsLocalBrainToOpen)
    }

    func testFacultyResearchNeedsLocalBrainUntilResearchProseExists() {
        XCTAssertTrue(SurfaceReadinessState(type: .facultyResearch).needsLocalBrainToOpen)
        XCTAssertTrue(SurfaceReadinessState(type: .facultyResearch, metadata: ["researchProse": ""]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .facultyResearch, metadata: ["researchProse": "The folio is ready."]).needsLocalBrainToOpen)
    }

    func testOtherPagesDoNotNeedLocalBrainToOpen() {
        XCTAssertFalse(SurfaceReadinessState(type: .mood).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .gossip, metadata: ["gossipProse": "The whisper is ready."]).needsLocalBrainToOpen)
        XCTAssertFalse(SurfaceReadinessState(type: .weather).needsLocalBrainToOpen)
    }

    func testCanInitializeFromSurfacePage() {
        let surface = SurfacePage(
            type: .narrativeOS,
            sourceID: "narrative-os",
            prompt: "The Story Page is stirring.",
            detail: "A page is gathering.",
            payload: BookPagePayload(
                headline: "Story Page",
                body: "The page has dried.",
                metadata: ["storyScene": "The page has dried."]
            )
        )

        XCTAssertFalse(SurfaceReadinessState(surface: surface).needsLocalBrainToOpen)
    }
}
