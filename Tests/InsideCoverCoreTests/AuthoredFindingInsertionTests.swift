import XCTest
@testable import InsideCoverCore

final class AuthoredFindingInsertionTests: XCTestCase {
    let scope = AuthoredContentScope(scopeID: "issue", runID: "run", phaseID: "climax")
    let insertion = AuthoredFindingInsertion(contentID: "invitation", marker: "{invitation}",
        quotationTemplate: "The Book opens: {sentence}", fallback: "An empty chair.",
        interpretations: ["light": "A fictional lamp stays lit."])

    func testInsertionUsesActualContributionAndScopedCompletedEvidence() throws {
        var page = BookPage(id: "finding", type: .narrativeOS, promptText: "Notice", userInput: "GENERATED PROSE",
                            playerReply: "A lamp beside an empty chair.", origin: .generated)
        let permission = AuthoredFindingPermission(mayUse: true, mayQuote: true, shape: "light",
            issueID: "issue", runID: "run", contentID: "invitation")
        page.tags.append(try XCTUnwrap(permission.retainedTag))
        let receipt = AuthoredContentReceipt(contentID: "invitation", occurrenceID: "return", channel: .storyScene,
            scope: scope, state: .completed, recordedAt: Date(), evidencePageIDs: [page.id])
        let ledger = AuthoredContentReceiptLedger(receipts: [receipt])
        XCTAssertEqual(insertion.render(scope: scope, ledger: ledger, pages: [page]),
            "The Book opens: A lamp beside an empty chair.\n\nA fictional lamp stays lit.")
        XCTAssertEqual(insertion.render(scope: scope, ledger: ledger, pages: []), insertion.fallback)
        var wrongRun = scope
        wrongRun.runID = "another-year"
        XCTAssertEqual(insertion.render(scope: wrongRun, ledger: ledger, pages: [page]), insertion.fallback)
        var accepted = receipt
        accepted.state = .accepted
        XCTAssertEqual(insertion.render(scope: scope, ledger: .init(receipts: [accepted]), pages: [page]), insertion.fallback)
        page.privacy = .localSensitive
        XCTAssertEqual(insertion.render(scope: scope, ledger: ledger, pages: [page]), insertion.fallback)
    }

    func testBookProseIsNeverSubstitutedForMissingReaderWords() {
        let page = BookPage(id: "generated", type: .bookOfYou, promptText: "Tonight", userInput: "Invented observation", origin: .generated)
        let receipt = AuthoredContentReceipt(contentID: "invitation", occurrenceID: "return", channel: .storyScene,
            scope: scope, state: .completed, recordedAt: Date(), evidencePageIDs: [page.id])
        XCTAssertEqual(insertion.render(scope: scope, ledger: .init(receipts: [receipt]), pages: [page]), insertion.fallback)
    }

    func testCarryForwardUsesOnlyMatchingRunAndLeavesFreshChoiceOtherwise() {
        let choices = ["terms", "rule", "ruse"].map {
            AuthoredStorySceneChoice(id: $0, title: $0, prompt: $0, result: $0)
        }
        var scene = AuthoredStoryScene(id: "ending", packID: "issue", eventID: "event", title: "Ending", opening: "Open", prompt: "Choose", detail: "")
        scene.nodes = [AuthoredStoryNode(id: "ending.choice", title: "Ending", body: "Open", prompt: "Choose", choices: choices,
            carryForward: .init(contentID: "strategy", nodeID: "strategy.choice", choiceMap: ["hunt": "rule"]))]
        let receipt = AuthoredContentReceipt(contentID: "strategy", occurrenceID: "choice", channel: .storyScene,
            scope: scope, state: .nodeCompleted, recordedAt: Date(), choiceID: "hunt", nodeID: "strategy.choice")
        let ledger = AuthoredContentReceiptLedger(receipts: [receipt])
        XCTAssertEqual(AuthoredStoryProgress.currentNode(scene: scene, contentID: scene.id, scope: scope, ledger: ledger)?.choices.map(\.id), ["rule"])
        var different = scope
        different.runID = "different"
        XCTAssertEqual(AuthoredStoryProgress.currentNode(scene: scene, contentID: scene.id, scope: different, ledger: ledger)?.choices.count, 3)
    }
}
