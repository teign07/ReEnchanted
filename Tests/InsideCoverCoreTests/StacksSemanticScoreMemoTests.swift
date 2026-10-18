import XCTest
@testable import InsideCoverCore

final class StacksSemanticScoreMemoTests: XCTestCase {
    func testConcurrentRefreshesComputeAnExactScoreOnlyOnce() {
        let memo = StacksSemanticScoreMemo()
        let probe = ScoreProbe()
        DispatchQueue.concurrentPerform(iterations: 24) { _ in
            let result = memo.value(modelID: "sentence-model", query: "porch light", document: "I left it on.") {
                probe.computed()
                return 0.73
            }
            probe.received(result)
        }
        XCTAssertEqual(probe.computeCount, 1)
        XCTAssertEqual(probe.results.count, 24)
        XCTAssertTrue(probe.results.allSatisfy { $0 == 0.73 })
    }

    func testChangedTextAndModelsDoNotReuseOldScoresAndMissingScoresAreMemoized() {
        let memo = StacksSemanticScoreMemo()
        var count = 0
        func score(_ model: String, _ query: String, _ document: String) -> Double? {
            memo.value(modelID: model, query: query, document: document) {
                count += 1
                return nil
            }
        }
        XCTAssertNil(score("one", "home", "first"))
        XCTAssertNil(score("one", "home", "first"))
        XCTAssertEqual(count, 1)
        _ = score("two", "home", "first")
        _ = score("one", "away", "first")
        _ = score("one", "home", "edited")
        XCTAssertEqual(count, 4)
        memo.clear()
        _ = score("one", "home", "first")
        XCTAssertEqual(count, 5)
    }

    func testCancelledRefreshUsesNeitherCachedScoresNorNewNativeCalls() async {
        let memo = StacksSemanticScoreMemo()
        let probe = ScoreProbe()
        _ = memo.value(modelID: "one", query: "home", document: "known") { 0.73 }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let cached = memo.value(modelID: "one", query: "home", document: "known") {
                probe.computed()
                return 0.5
            }
            let missing = memo.value(modelID: "one", query: "home", document: "new") {
                probe.computed()
                return 0.5
            }
            return (cached, missing)
        }
        let results = await task.value
        XCTAssertNil(results.0)
        XCTAssertNil(results.1)
        XCTAssertEqual(probe.computeCount, 0)
    }
}

private final class ScoreProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private var values: [Double?] = []

    var computeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    var results: [Double?] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    func computed() {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
    }

    func received(_ value: Double?) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }
}
