import XCTest
@testable import InsideCoverCore

final class PreparedPageRecoveryStateTests: XCTestCase {
    func testShouldBeginWhenNoWorkIsRunningNoCooldownAndNoPreparedSurfaceExists() {
        let recovery = PreparedPageRecoveryState()

        XCTAssertTrue(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: nil,
            slotID: "slot-1",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testShouldNotBeginWhileAlreadyPreparing() {
        let recovery = PreparedPageRecoveryState()

        XCTAssertFalse(recovery.shouldBegin(
            isPreparing: true,
            isLocalBrainWorking: false,
            preparedSurface: nil,
            slotID: "slot-1",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testShouldNotBeginWhileLocalBrainIsWorking() {
        let recovery = PreparedPageRecoveryState()

        XCTAssertFalse(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: true,
            preparedSurface: nil,
            slotID: "slot-1",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testFailureStartsCooldownUntilCooldownExpires() {
        let failureDate = Date()
        var recovery = PreparedPageRecoveryState(cooldown: 20 * 60)

        recovery.recordFailure(at: failureDate)

        XCTAssertTrue(recovery.isCoolingDown(now: failureDate.addingTimeInterval(19 * 60)))
        XCTAssertFalse(recovery.isCoolingDown(now: failureDate.addingTimeInterval(20 * 60)))
    }

    func testSuccessClearsCooldown() {
        var recovery = PreparedPageRecoveryState(cooldown: 20 * 60)
        recovery.recordFailure(at: Date())

        recovery.recordSuccess()

        XCTAssertFalse(recovery.isCoolingDown(now: Date()))
    }

    func testCurrentPreparedSurfaceBlocksAnotherAttempt() {
        let recovery = PreparedPageRecoveryState()
        let surface = preparedSurface(slotID: "slot-1", storyScene: "A page has dried.")

        XCTAssertFalse(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: surface,
            slotID: "slot-1",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testPreparedSurfaceMissingRequiredProseAllowsAnotherAttempt() {
        let recovery = PreparedPageRecoveryState()
        let surface = preparedSurface(slotID: "slot-1", storyScene: "")

        XCTAssertTrue(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: surface,
            slotID: "slot-1",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testPreparedSurfaceFromDifferentSlotAllowsAnotherAttempt() {
        let recovery = PreparedPageRecoveryState()
        let surface = preparedSurface(slotID: "slot-1", storyScene: "A page has dried.")

        XCTAssertTrue(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: surface,
            slotID: "slot-2",
            requiredMetadataKey: "storyScene",
            now: Date()
        ))
    }

    func testCurrentPreparedSurfaceUsesRequestedMetadataKey() {
        let recovery = PreparedPageRecoveryState()
        let surface = preparedSurface(
            slotID: "slot-1",
            metadataKey: "gossipProse",
            prose: "The margins whispered something specific."
        )

        XCTAssertFalse(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: surface,
            slotID: "slot-1",
            requiredMetadataKey: "gossipProse",
            now: Date()
        ))
        XCTAssertTrue(recovery.shouldBegin(
            isPreparing: false,
            isLocalBrainWorking: false,
            preparedSurface: surface,
            slotID: "slot-1",
            requiredMetadataKey: "researchProse",
            now: Date()
        ))
    }

    private func preparedSurface(slotID: String, storyScene: String) -> SurfacePage {
        preparedSurface(slotID: slotID, metadataKey: "storyScene", prose: storyScene)
    }

    private func preparedSurface(slotID: String, metadataKey: String, prose: String) -> SurfacePage {
        SurfacePage(
            id: "story-\(slotID)",
            type: .narrativeOS,
            sourceID: "narrative-os",
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 80,
            reason: "The story field is ready.",
            prompt: "The Story Page is stirring.",
            detail: "A page is gathering.",
            payload: BookPagePayload(
                headline: "Story Page",
                body: prose,
                metadata: [
                    "slotID": slotID,
                    metadataKey: prose
                ]
            )
        )
    }
}
