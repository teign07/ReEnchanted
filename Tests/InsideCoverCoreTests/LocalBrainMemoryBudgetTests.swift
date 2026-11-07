import XCTest
@testable import InsideCoverCore

final class LocalBrainMemoryBudgetTests: XCTestCase {
    func testAHealthyWarmRunKeepsItsWorkingRoom() {
        var budget = LocalBrainMemoryBudget()
        XCTAssertTrue(budget.observe(availableBytes: 360 * 1_024 * 1_024,
                                     minimumBytes: LocalBrainMemoryBudget.prefillHeadroom))
        XCTAssertTrue(budget.observe(availableBytes: 240 * 1_024 * 1_024))
        XCTAssertFalse(budget.stopped)
    }

    func testPrefillNeedsMoreRoomThanAnAlreadyRunningTokenLoop() {
        var prefill = LocalBrainMemoryBudget()
        var running = LocalBrainMemoryBudget()
        let available: UInt64 = 256 * 1_024 * 1_024
        XCTAssertFalse(prefill.observe(availableBytes: available,
                                      minimumBytes: LocalBrainMemoryBudget.prefillHeadroom))
        XCTAssertTrue(running.observe(availableBytes: available))
    }

    func testPressureRemainsTerminalAfterCleanupReturnsMemory() {
        var budget = LocalBrainMemoryBudget()
        XCTAssertFalse(budget.observe(availableBytes: LocalBrainMemoryBudget.stopHeadroom - 1))
        XCTAssertFalse(budget.observe(availableBytes: 3 * 1_024 * 1_024 * 1_024),
                       "Cleanup cannot turn a cancelled partial reply into a finished page")
        XCTAssertTrue(budget.stopped)
        var nextRun = LocalBrainMemoryBudget()
        XCTAssertTrue(nextRun.observe(availableBytes: 3 * 1_024 * 1_024 * 1_024))
    }

    func testZeroIsExhaustionRatherThanAnUnknownAllowance() {
        var budget = LocalBrainMemoryBudget()
        XCTAssertFalse(budget.observe(availableBytes: 0))
        XCTAssertTrue(budget.stopped)
    }

    func testTheFloorIsInclusive() {
        var budget = LocalBrainMemoryBudget()
        XCTAssertTrue(budget.observe(availableBytes: LocalBrainMemoryBudget.stopHeadroom))
        XCTAssertFalse(budget.observe(availableBytes: LocalBrainMemoryBudget.stopHeadroom - 1))
    }
}
