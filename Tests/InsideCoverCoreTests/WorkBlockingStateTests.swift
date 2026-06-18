import XCTest
@testable import InsideCoverCore

final class WorkBlockingStateTests: XCTestCase {
    func testLabWorkStatusPrefersLocalBrainStatus() {
        let state = WorkBlockingState(
            isLocalBrainWorking: true,
            localBrainStatus: "Story Page · 1200 chars · 1 queued",
            isBraiding: true,
            isPreparingAutomaticIllumination: true,
            isPreparingStoryPage: true,
            isPreparingGossipPage: true,
            isPreparingFacultyResearchPage: true
        )

        XCTAssertEqual(state.labWorkStatus, "Story Page · 1200 chars · 1 queued")
    }

    func testLabWorkStatusFallsThroughActiveWorkInDisplayOrder() {
        XCTAssertEqual(WorkBlockingState(isBraiding: true).labWorkStatus, "braiding")
        XCTAssertEqual(WorkBlockingState(isPreparingAutomaticIllumination: true).labWorkStatus, "preparing illumination")
        XCTAssertEqual(WorkBlockingState(isPreparingStoryPage: true).labWorkStatus, "preparing story")
        XCTAssertEqual(WorkBlockingState(isPreparingGossipPage: true).labWorkStatus, "preparing gossip")
        XCTAssertEqual(WorkBlockingState(isPreparingFacultyResearchPage: true).labWorkStatus, "preparing faculty research")
        XCTAssertEqual(WorkBlockingState().labWorkStatus, "idle")
    }

    func testLocalBrainBlocksOnlySurfacesThatNeedIt() {
        let state = WorkBlockingState(isLocalBrainWorking: true)

        XCTAssertFalse(state.canOpenSurface(needsLocalBrain: true))
        XCTAssertTrue(state.canOpenSurface(needsLocalBrain: false))
    }

    func testBookOfYouShowsBusyIndicatorOnlyWhileBraiding() {
        XCTAssertTrue(WorkBlockingState(isBraiding: true).surfaceBusyIndicator(for: .bookOfYou))
        XCTAssertFalse(WorkBlockingState(isBraiding: true).surfaceBusyIndicator(for: .mood))
        XCTAssertFalse(WorkBlockingState(isBraiding: false).surfaceBusyIndicator(for: .bookOfYou))
    }

    func testBraidCannotStartDuringBraidOrLocalBrainWork() {
        XCTAssertTrue(WorkBlockingState().canStartBraid)
        XCTAssertFalse(WorkBlockingState(isBraiding: true).canStartBraid)
        XCTAssertFalse(WorkBlockingState(isLocalBrainWorking: true).canStartBraid)
    }

    func testWeatherCannotStartDuringLocalBrainWork() {
        XCTAssertTrue(WorkBlockingState().canRequestWeather)
        XCTAssertFalse(WorkBlockingState(isLocalBrainWorking: true).canRequestWeather)
    }
}
