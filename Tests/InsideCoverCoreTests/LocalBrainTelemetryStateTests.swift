import XCTest
@testable import InsideCoverCore

final class LocalBrainTelemetryStateTests: XCTestCase {
    func testWakeAndRestTrackReadingRoomState() {
        var telemetry = LocalBrainTelemetryState()

        telemetry.wake()
        XCTAssertTrue(telemetry.isReading)

        telemetry.rest()
        XCTAssertFalse(telemetry.isReading)
    }

    func testBeginWorkStartsTelemetryAndReturnsTrueOnlyForFirstSnapshot() {
        var telemetry = LocalBrainTelemetryState()
        let startedAt = Date(timeIntervalSince1970: 100)

        let didBegin = telemetry.beginOrUpdateWork(
            label: "Story Page",
            promptCharacters: 1234,
            queuedCount: 2,
            now: startedAt
        )
        let didUpdate = telemetry.beginOrUpdateWork(
            label: "Story Page",
            promptCharacters: 1500,
            queuedCount: 1,
            now: startedAt.addingTimeInterval(5)
        )

        XCTAssertTrue(didBegin)
        XCTAssertFalse(didUpdate)
        XCTAssertTrue(telemetry.isWorking)
        XCTAssertEqual(telemetry.currentLabel, "Story Page")
        XCTAssertEqual(telemetry.currentPromptCharacters, 1500)
        XCTAssertEqual(telemetry.currentQueuedCount, 1)
        XCTAssertEqual(telemetry.startedAt, startedAt)
        XCTAssertEqual(telemetry.lastLabel, "Story Page")
        XCTAssertEqual(telemetry.lastPromptCharacters, 1500)
    }

    func testNilWorkLabelFallsBackToBook() {
        var telemetry = LocalBrainTelemetryState()

        _ = telemetry.beginOrUpdateWork(label: nil, promptCharacters: 42, queuedCount: 0)

        XCTAssertEqual(telemetry.currentLabel, "the Book")
        XCTAssertEqual(telemetry.lastLabel, "the Book")
    }

    func testFinishWorkClearsTransientCountersAndRecordsFinishTime() {
        var telemetry = LocalBrainTelemetryState()
        _ = telemetry.beginOrUpdateWork(label: "Gossip Page", promptCharacters: 800, queuedCount: 3)
        let finishedAt = Date(timeIntervalSince1970: 200)

        telemetry.finishWork(now: finishedAt)

        XCTAssertFalse(telemetry.isWorking)
        XCTAssertNil(telemetry.startedAt)
        XCTAssertEqual(telemetry.currentPromptCharacters, 0)
        XCTAssertEqual(telemetry.currentQueuedCount, 0)
        XCTAssertEqual(telemetry.lastFinishedAt, finishedAt)
        XCTAssertEqual(telemetry.lastLabel, "Gossip Page")
        XCTAssertEqual(telemetry.lastPromptCharacters, 800)
    }

    func testResetTransientWorkClearsReadingAndActiveWorkWithoutClearingLastSummary() {
        var telemetry = LocalBrainTelemetryState()
        telemetry.wake()
        _ = telemetry.beginOrUpdateWork(label: "Faculty Research", promptCharacters: 640, queuedCount: 1)

        telemetry.resetTransientWork()

        XCTAssertFalse(telemetry.isReading)
        XCTAssertFalse(telemetry.isWorking)
        XCTAssertNil(telemetry.startedAt)
        XCTAssertEqual(telemetry.currentPromptCharacters, 0)
        XCTAssertEqual(telemetry.currentQueuedCount, 0)
        XCTAssertEqual(telemetry.lastLabel, "Faculty Research")
        XCTAssertEqual(telemetry.lastPromptCharacters, 640)
    }

    func testStatusStringsUseCurrentAndLastWork() {
        var telemetry = LocalBrainTelemetryState()
        _ = telemetry.beginOrUpdateWork(label: "Braid", promptCharacters: 900, queuedCount: 4)

        XCTAssertEqual(telemetry.currentWorkStatus, "Braid · 900 chars · 4 queued")

        telemetry.finishWork(now: Date(timeIntervalSince1970: 300))

        XCTAssertNil(telemetry.currentWorkStatus)
        XCTAssertEqual(telemetry.lastWorkStatus { _ in "12:00:00" }, "Braid · 900 chars · 12:00:00")
    }

    func testErrorCanBeRecordedAndCleared() {
        var telemetry = LocalBrainTelemetryState()

        telemetry.recordError("story page: failed")
        XCTAssertEqual(telemetry.lastError, "story page: failed")

        telemetry.clearError()
        XCTAssertNil(telemetry.lastError)
    }
}
