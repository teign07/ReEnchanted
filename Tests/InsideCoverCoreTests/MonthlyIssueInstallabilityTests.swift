import ImageIO
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

    private struct MediaRule: Decodable {
        var prefix: String
        var directory: String
        var suffix: String
    }

    private struct AudioRule: Decodable {
        var directory: String
        var files: [String: String]
    }

    private struct Issue: Decodable {
        var issueID: String
        var files: [IssueFile]
        var media: [MediaRule]?
        var audio: AudioRule?
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

    /// Marks are files on the reader's phone, decoded by the same ImageIO call
    /// `BookMarginaliaImage` makes. A pack can pass every JSON check and still
    /// ship a mark that is empty, truncated, or not an image, and the reader
    /// sees a blank tile with nothing to say why. This holds every issue folder
    /// that exists, so a new month is covered the day its folder appears.
    func testEveryShippedMarkDecodesAndEveryReferenceResolves() throws {
        let folders = try FileManager.default.contentsOfDirectory(at: contentPacks, includingPropertiesForKeys: nil)
        var checked = 0
        for folder in folders {
            let issueURL = folder.appendingPathComponent("issue.json")
            guard FileManager.default.fileExists(atPath: issueURL.path) else { continue }
            let issue = try JSONDecoder().decode(Issue.self, from: Data(contentsOf: issueURL))
            var declared = Set(issue.files.map(\.id))
            for rule in issue.media ?? [] {
                let directory = folder.appendingPathComponent(rule.directory)
                let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
                for name in names where name.hasSuffix(rule.suffix) {
                    let id = rule.prefix + String(name.dropLast(rule.suffix.count))
                    declared.insert(id)
                    guard ["png", "jpg", "jpeg"].contains(rule.suffix.dropFirst().lowercased()) else { continue }
                    let url = directory.appendingPathComponent(name)
                    let image = CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
                        CGImageSourceCreateThumbnailAtIndex($0, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: 1_536
                        ] as CFDictionary)
                    }
                    XCTAssertNotNil(image, "\(issue.issueID): \(id) is not an image the app can decode")
                    XCTAssertGreaterThan(image?.width ?? 0, 8, "\(issue.issueID): \(id) decodes to a speck")
                    checked += 1
                }
            }
            if let audio = issue.audio {
                for (id, file) in audio.files {
                    declared.insert(id)
                    XCTAssertTrue(
                        FileManager.default.fileExists(atPath: folder.appendingPathComponent(audio.directory).appendingPathComponent(file).path),
                        "\(issue.issueID): \(id) names a recording that is not in the folder")
                }
            }
            for file in issue.files {
                let text = try String(contentsOf: folder.appendingPathComponent(file.source), encoding: .utf8)
                let refs = try NSRegularExpression(pattern: #"\{\{asset-path:([^}]+)\}\}"#)
                    .matches(in: text, range: NSRange(text.startIndex..., in: text))
                    .compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
                for ref in refs {
                    XCTAssertTrue(declared.contains(ref),
                                  "\(issue.issueID): \(file.source) points at \(ref), which the issue never ships")
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "no mark images were found; the folder layout changed")
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
