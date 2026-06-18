import XCTest
@testable import InsideCoverCore

final class SurfaceActionRouterTests: XCTestCase {
    func testReadyNonBraidSurfaceOpens() {
        let router = SurfaceActionRouter(workState: WorkBlockingState())

        XCTAssertEqual(
            router.decision(for: .mood, readiness: SurfaceReadinessState(type: .mood)),
            .open
        )
    }

    func testBookOfYouBraidsWhenWorkIsAvailable() {
        let router = SurfaceActionRouter(workState: WorkBlockingState())

        XCTAssertEqual(
            router.decision(for: .bookOfYou, readiness: SurfaceReadinessState(type: .bookOfYou)),
            .braid
        )
    }

    func testSurfaceNeedingLocalBrainBlocksWhileLocalBrainIsWorking() {
        let router = SurfaceActionRouter(workState: WorkBlockingState(isLocalBrainWorking: true))

        XCTAssertEqual(
            router.decision(for: .narrativeOS, readiness: SurfaceReadinessState(type: .narrativeOS)),
            .blocked(message: "The Book is already writing. One moment, please.")
        )
    }

    func testBookOfYouBlocksBeforeBraidWhileLocalBrainIsWorking() {
        let router = SurfaceActionRouter(workState: WorkBlockingState(isLocalBrainWorking: true))

        XCTAssertEqual(
            router.decision(for: .bookOfYou, readiness: SurfaceReadinessState(type: .bookOfYou)),
            .blocked(message: "The Book is already writing. One moment, please.")
        )
    }

    func testReadyGeneratedSurfaceCanOpenWhileLocalBrainIsWorking() {
        let router = SurfaceActionRouter(workState: WorkBlockingState(isLocalBrainWorking: true))
        let readiness = SurfaceReadinessState(
            type: .narrativeOS,
            metadata: ["storyScene": "The page has dried."]
        )

        XCTAssertEqual(router.decision(for: .narrativeOS, readiness: readiness), .open)
    }
}
