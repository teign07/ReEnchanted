import XCTest
@testable import InsideCoverCore

final class MomentaryEngagementTests: XCTestCase {
    func testMasteryAdvancesByDistinctMeaningfulPages() {
        var learning = ReaderLearningModel()
        XCTAssertEqual(ReaderAttentionMasteryStage.current(for: learning), .notice)

        for index in 0..<4 {
            learning.record(event(.acted, surfaceID: "notice-\(index)"))
        }
        XCTAssertEqual(ReaderAttentionMasteryStage.current(for: learning), .name)

        for index in 4..<12 {
            learning.record(event(.kept, surfaceID: "name-\(index)"))
        }
        XCTAssertEqual(ReaderAttentionMasteryStage.current(for: learning), .connect)

        for index in 12..<30 {
            learning.record(event(.followedThread, surfaceID: "connect-\(index)"))
        }
        XCTAssertEqual(ReaderAttentionMasteryStage.current(for: learning), .transform)
    }

    func testPromptIsImmediateForProsePageAndDefersToNativeRitual() {
        let learning = ReaderLearningModel()
        let prose = SurfacePage(type: .diary, prompt: "Look again.", detail: "A detail.")
        let tarot = SurfacePage(type: .tarot, prompt: "Draw.", detail: "Three cards.")

        XCTAssertEqual(
            MomentaryAttentionEngine.prompt(for: prose, learning: learning)?.question,
            "What caught first?"
        )
        XCTAssertNil(MomentaryAttentionEngine.prompt(for: tarot, learning: learning))
    }

    func testRecognitionReturnsTheReadersExactWordsImmediately() {
        let line = MomentaryAttentionEngine.recognition(
            for: "the blue cup",
            stage: .connect
        )
        XCTAssertTrue(line.contains("“the blue cup”"))
        XCTAssertTrue(line.contains("thread"))
    }

    func testMomentumTelemetryMeasuresOpenToActionWithoutSessionTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var learning = ReaderLearningModel()
        learning.record(event(.opened, surfaceID: "fast", at: start))
        learning.record(event(.acted, surfaceID: "fast", at: start.addingTimeInterval(8)))
        learning.record(event(.recognized, surfaceID: "fast", at: start.addingTimeInterval(8.1)))
        learning.record(event(.opened, surfaceID: "slow", at: start.addingTimeInterval(20)))
        learning.record(event(.acted, surfaceID: "slow", at: start.addingTimeInterval(65)))

        let metrics = learning.momentumMetrics()
        XCTAssertEqual(metrics.opened, 2)
        XCTAssertEqual(metrics.acted, 2)
        XCTAssertEqual(metrics.recognized, 1)
        XCTAssertEqual(metrics.actionsWithinThirtySeconds, 1)
        XCTAssertEqual(metrics.openToActionRatePercent, 50)
        XCTAssertEqual(metrics.medianOpenToActionSeconds ?? -1, 26.5, accuracy: 0.001)
    }

    func testNativeKeepActionIsNeededOnceAfterEachOpen() {
        let start = Date(timeIntervalSince1970: 1_000)
        var learning = ReaderLearningModel()

        XCTAssertFalse(learning.needsNativeAction(for: "page"))
        learning.record(event(.opened, surfaceID: "page", at: start))
        XCTAssertTrue(learning.needsNativeAction(for: "page"))
        learning.record(event(.acted, surfaceID: "page", at: start.addingTimeInterval(4)))
        XCTAssertFalse(learning.needsNativeAction(for: "page"))

        learning.record(event(.opened, surfaceID: "page", at: start.addingTimeInterval(20)))
        XCTAssertTrue(learning.needsNativeAction(for: "page"))
    }

    private func event(
        _ action: ReaderLearningAction,
        surfaceID: String,
        at occurredAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> ReaderLearningEvent {
        ReaderLearningEvent(
            dayID: "2026-07-18",
            occurredAt: occurredAt,
            action: action,
            surfaceID: surfaceID,
            sourceID: "test-source",
            type: .diary,
            varietyKey: "test",
            hour: 12
        )
    }
}
