import XCTest
@testable import InsideCoverCore

final class MonthlyIssueOfferFairnessTests: XCTestCase {
    func page(_ id: String, score: Int, priority: String) -> SurfacePage {
        SurfacePage(id: id, type: .narrativeOS, sourceID: "story", score: score, prompt: id, detail: "")
            .withMetadata([MonthlyIssuePageMetadata.issueID: "issue", MonthlyIssuePageMetadata.runID: "run",
                MonthlyIssuePageMetadata.contentID: id, MonthlyIssuePageMetadata.priority: priority,
                MonthlyIssuePageMetadata.claimHistoryKey: "daily-claim"])
    }

    func testUnopenedCrossingGetsNextOfferWithoutRetiringStory() {
        let story = page("story", score: 94, priority: "spine")
        let crossing = page("crossing", score: 90, priority: "featured")
        let receipt = AuthoredContentReceipt(contentID: "story", occurrenceID: "old-hour", channel: .storyScene,
            scope: .init(scopeID: "issue", runID: "run"), state: .opened, recordedAt: Date())
        let ledger = AuthoredContentReceiptLedger(receipts: [receipt])
        let result = MonthlyIssuePageCuration.fairlyOffering([story, crossing], ledger: ledger)
        XCTAssertEqual(result.map(\.id), ["story", "crossing"])
        XCTAssertEqual(result[0], story)
        XCTAssertGreaterThan(result[1].score, story.score)
        XCTAssertTrue(result[1].mayReserveAuthoredIssueSlot)
        XCTAssertEqual(result[1].payload.metadata[MonthlyIssuePageMetadata.claimHistoryKey], "daily-claim")
        XCTAssertEqual(ledger.receipts, [receipt])
    }

    func testFreshPoolKeepsAuthoredPriorityAndOtherRunDoesNotRotateIt() {
        let pages = [page("story", score: 94, priority: "spine"), page("crossing", score: 90, priority: "featured")]
        XCTAssertEqual(MonthlyIssuePageCuration.fairlyOffering(pages, ledger: .empty), pages)
        let receipt = AuthoredContentReceipt(contentID: "story", occurrenceID: "previous", channel: .storyScene,
            scope: .init(scopeID: "issue", runID: "last-year"), state: .opened, recordedAt: Date())
        XCTAssertEqual(MonthlyIssuePageCuration.fairlyOffering(pages, ledger: .init(receipts: [receipt])), pages)
    }
}
