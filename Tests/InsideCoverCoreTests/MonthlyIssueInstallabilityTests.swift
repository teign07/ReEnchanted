import XCTest
@testable import InsideCoverCore

/// Every file a monthly issue ships has to pass the check a reader's device
/// runs before it installs anything. Installs are all-or-nothing, so one file
/// that fails keeps the whole month off the shelf. October 2026 went out with
/// a paper-play pack the app couldn't decode, and no phone installed October.
/// The Python release pipeline checks bytes, not whether Swift can read them.
final class MonthlyIssueInstallabilityTests: XCTestCase {
    private struct IssueFile: Decodable {
        var id: String
        var kind: MonthlyIssueDeliveryAssetKind
        var source: String
        var scope: MonthlyIssueDeliveryAssetScope?
    }

    private struct Issue: Decodable {
        var issueID: String
        var files: [IssueFile]
    }

    private var contentPacks: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContentPacks")
    }

    func testEveryFileInEveryIssuePassesTheDeviceCheck() throws {
        let folders = try FileManager.default.contentsOfDirectory(at: contentPacks, includingPropertiesForKeys: nil)
        let issues = folders.map { $0.appendingPathComponent("issue.json") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertFalse(issues.isEmpty)
        for issueURL in issues {
            let issue = try JSONDecoder().decode(Issue.self, from: Data(contentsOf: issueURL))
            for file in issue.files {
                let data = try Data(contentsOf: issueURL.deletingLastPathComponent().appendingPathComponent(file.source))
                let asset = MonthlyIssueDeliveryAsset(
                    id: file.id, kind: file.kind, scope: file.scope ?? .runtime,
                    remoteURL: URL(string: "https://example.invalid/\(file.id)")!,
                    fileName: file.source, sha256: "", byteCount: data.count
                )
                XCTAssertNoThrow(
                    try MonthlyIssueAssetInstaller.validateMaterializedAsset(data, asset: asset),
                    "\(issue.issueID): \(file.id) would stop the whole issue installing"
                )
            }
        }
    }

    /// Authors leave defaulted fields out. That has to decode.
    func testAPlayLeafWithoutTheOptionalFieldsDecodes() throws {
        let json = """
        {"id":"leaf","title":"T","contentsListing":"C","instruction":"I","form":"map",
         "cadence":"weekly","templateSlot":"weeklyInterruption","footprint":"rectoWithBlankReverse",
         "eventPhaseIDs":["p"],"prompts":[{"id":"q","label":"L"}]}
        """
        let leaf = try ContentPackFileLocator.decoder().decode(EditionPlayLeaf.self, from: Data(json.utf8))
        XCTAssertEqual(leaf.eventOutcomeIDs, [])
        XCTAssertEqual(leaf.options, [])
        XCTAssertEqual(leaf.prompts.first?.writingLines, 1)
    }
}
