import XCTest
@testable import InsideCoverCore

final class StacksSearchPassReuseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_080_000)

    private var dataset: StacksSearchDataset {
        let pages = [
            BookPage(id: "lantern", type: .souvenir, createdAt: now,
                     promptText: "A copper lantern beside the window.", userInput: "The rain made it shine."),
            BookPage(id: "garden", type: .souvenir, createdAt: now.addingTimeInterval(-60),
                     promptText: "The green garden gate.", userInput: "Moss has covered the latch.")
        ]
        return StacksSearchDataset(days: [BookDay(id: "2026-10-15", date: now, pages: pages)])
    }

    func testReusedQuickPassPreservesHybridRankingSnippetsAndSemanticOnlyFindings() {
        let quick = StacksSearchEngine.search("lantern", in: dataset, now: now)
        XCTAssertFalse(quick.isEmpty)
        XCTAssertFalse(quick.contains { $0.referenceID == "garden" })
        let expected = StacksSearchEngine.hybridSearch(
            "lantern", in: dataset, now: now, semanticScorer: ConstantScorer()
        )
        let reused = StacksSearchEngine.hybridSearch(
            "lantern", in: dataset, now: now, semanticScorer: ConstantScorer(),
            precomputedLexicalResults: quick
        )
        XCTAssertEqual(reused, expected)
        XCTAssertTrue(reused.contains { $0.referenceID == "garden" })
    }

    func testMissingSemanticModelKeepsTheExactQuickPass() {
        let quick = StacksSearchEngine.search("lantern", in: dataset, now: now)
        let result = StacksSearchEngine.hybridSearch(
            "lantern", in: dataset, now: now, semanticScorer: nil,
            precomputedLexicalResults: quick
        )
        XCTAssertEqual(result, quick)
    }

    func testCancelledDeepPassReturnsQuickFindingsWithoutCallingTheScorer() async {
        let archive = dataset
        let time = now
        let quick = StacksSearchEngine.search("lantern", in: archive, now: time)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return StacksSearchEngine.hybridSearch(
                "lantern", in: archive, now: time, semanticScorer: UnexpectedScorer(),
                precomputedLexicalResults: quick
            )
        }
        let result = await task.value
        XCTAssertEqual(result, quick)
    }
}

/// Close in meaning only to the two Pages under test. A scorer that likes every document
/// equally ties the whole graph (the source families are documents too) and pushes the
/// semantic-only Page past the result limit, which says nothing about pass reuse.
private struct ConstantScorer: StacksSemanticScoring {
    let modelID = "pass-reuse-test"
    func similarity(between query: String, and document: String) -> Double? {
        document.contains("garden") || document.contains("lantern") ? 0.62 : nil
    }
}

private struct UnexpectedScorer: StacksSemanticScoring {
    let modelID = "cancelled-pass-test"
    func similarity(between query: String, and document: String) -> Double? {
        XCTFail("A cancelled pass must not enter semantic scoring.")
        return 0.62
    }
}
