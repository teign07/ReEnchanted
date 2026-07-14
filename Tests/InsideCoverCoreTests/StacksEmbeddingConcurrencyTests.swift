import XCTest
@testable import InsideCoverCore

#if canImport(NaturalLanguage)
final class StacksEmbeddingConcurrencyTests: XCTestCase {
    func testNaturalLanguageDistanceCallsAreSafeAcrossConcurrentSurfaceBuilds() throws {
        guard let scorer = NaturalLanguageStacksEmbeddingScorer() else {
            throw XCTSkip("The system sentence embedding is unavailable.")
        }
        let resultLock = NSLock()
        var results: [Double?] = []

        DispatchQueue.concurrentPerform(iterations: 24) { index in
            let similarity = scorer.similarity(
                between: "friendship repair, homecoming, trust, and a green scarf",
                and: "Passage \(index): I folded the apology into the green scarf and carried it home."
            )
            resultLock.lock()
            results.append(similarity)
            resultLock.unlock()
        }

        XCTAssertEqual(results.count, 24)
        XCTAssertTrue(results.allSatisfy { $0 != nil })
    }
}
#endif
