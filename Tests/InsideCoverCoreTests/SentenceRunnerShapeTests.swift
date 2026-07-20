import XCTest
@testable import InsideCoverCore

final class SentenceRunnerShapeTests: XCTestCase {
    func testShapeSelectionIsDeterministicForASurfaceSeed() {
        XCTAssertEqual(
            SentenceRunnerRunShape.selected(seed: "2026-07-18-4-sentence-runner-shape"),
            SentenceRunnerRunShape.selected(seed: "2026-07-18-4-sentence-runner-shape")
        )
    }

    func testEveryShapeHasADistinctPlayableCadence() {
        let durations = Set(SentenceRunnerRunShape.allCases.map(\.runDuration))
        let speeds = Set(SentenceRunnerRunShape.allCases.map(\.scrollSpeed))

        XCTAssertEqual(durations.count, SentenceRunnerRunShape.allCases.count)
        XCTAssertEqual(speeds.count, SentenceRunnerRunShape.allCases.count)
        XCTAssertTrue(SentenceRunnerRunShape.allCases.allSatisfy { !$0.title.isEmpty && !$0.invitation.isEmpty })
    }
}
