import XCTest
@testable import InsideCoverCore

/// `talksAboutTheLocalBrain` was lifted out of CapturePageSheet so the opened
/// Page and the leaf could both offer the waking button from one rule. These pin
/// the extracted behaviour to what the sheet did, because a quiet change here
/// means either two surfaces disagreeing or the button vanishing from both.
final class LocalBrainPagePredicateTests: XCTestCase {
    private func page(_ metadata: [String: String]) -> SurfacePage {
        SurfacePage(
            id: "probe",
            type: .welcome,
            sourceID: "probe",
            score: 10,
            prompt: "probe",
            detail: "probe",
            payload: BookPagePayload(headline: "probe", body: "probe", metadata: metadata)
        )
    }

    func testAPageSourcedFromTheLocalBrainTalksAboutIt() {
        XCTAssertTrue(page(["source": "local-brain"]).talksAboutTheLocalBrain)
    }

    func testAFailedPageTalksAboutIt() {
        XCTAssertTrue(page(["status": "failed"]).talksAboutTheLocalBrain)
    }

    /// The welcome Page and the recovery rider are found by tag, which is how
    /// the sheet found them.
    func testTaggedPagesTalkAboutIt() {
        XCTAssertTrue(page(["tags": "welcome,local-brain"]).talksAboutTheLocalBrain)
        XCTAssertTrue(page(["tags": "colophon"]).talksAboutTheLocalBrain)
        XCTAssertTrue(page(["tags": "a,local-brain,b"]).talksAboutTheLocalBrain)
    }

    func testAnOrdinaryPageDoesNot() {
        XCTAssertFalse(page([:]).talksAboutTheLocalBrain)
        XCTAssertFalse(page(["tags": "diary,evening"]).talksAboutTheLocalBrain)
        XCTAssertFalse(page(["source": "diary", "status": "ready"]).talksAboutTheLocalBrain)
    }
}
