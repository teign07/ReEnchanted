import Foundation
import XCTest

@testable import InsideCoverCore

/// How a page will sit on the leaves once it is set.
///
/// Pages Rising became a bound book, so length stopped being a number measured
/// against a band and became a physical shape: the paginator measures real text
/// and starts a new leaf when a block overflows. Two drafts forty words apart
/// can set very differently, and nothing in the taste engines could see it.
final class FolioSettingTests: XCTestCase {
    private func paragraphs(_ count: Int, charactersEach: Int) -> String {
        (0..<count)
            .map { _ in String(repeating: "a", count: charactersEach) }
            .joined(separator: "\n\n")
    }

    /// A glimpse braid is one leaf; a full braid is several. That mapping is
    /// the whole reason this exists.
    func testAShortPageSitsOnOneLeaf() {
        let set = FolioSetting.setting(of: paragraphs(2, charactersEach: 120))
        XCTAssertEqual(set.leaves, 1)
        XCTAssertFalse(set.strandsAnOrphan)
    }

    func testALongPageRunsOntoMoreLeaves() {
        let short = FolioSetting.setting(of: paragraphs(3, charactersEach: 200))
        let long = FolioSetting.setting(of: paragraphs(9, charactersEach: 200))
        XCTAssertGreaterThan(long.leaves, short.leaves)
    }

    /// Paragraphs do not share lines. Ignoring that undercounts a page of short
    /// paragraphs badly, which is most braids.
    func testEachParagraphRoundsUpOnItsOwn() {
        let oneBlock = FolioSetting.lineCount(
            of: String(repeating: "a", count: 66), charactersPerLine: 33)
        let twoBlocks = FolioSetting.lineCount(
            of: "\(String(repeating: "a", count: 34))\n\n\(String(repeating: "a", count: 32))",
            charactersPerLine: 33)
        XCTAssertEqual(oneBlock, 2)
        XCTAssertEqual(twoBlocks, 3)
    }

    /// The failure the reader actually feels: turning a leaf to find two lines
    /// on it, with the Book apologising in the margin.
    func testAnOrphanedLastLeafIsPenalised() {
        let geometry = FolioSetting.Geometry(
            charactersPerLine: 33, linesPerLeaf: 14, linesLostToOpeningFurniture: 4)
        // Ten lines fill the opening leaf, then one line strands.
        let stranded = FolioSetting.setting(
            of: paragraphs(11, charactersEach: 30), geometry: geometry)
        XCTAssertTrue(stranded.strandsAnOrphan, "\(stranded)")
        let points = FolioSetting.signals(for: paragraphs(11, charactersEach: 30), geometry: geometry)
            .reduce(0) { $0 + $1.points }
        XCTAssertLessThan(points, 0)
    }

    /// A page that fills its last leaf is preferred over one that dribbles.
    func testAFullLastLeafIsPreferredToAnOrphan() {
        let geometry = FolioSetting.Geometry(
            charactersPerLine: 33, linesPerLeaf: 14, linesLostToOpeningFurniture: 4)
        func points(_ text: String) -> Int {
            FolioSetting.signals(for: text, geometry: geometry).reduce(0) { $0 + $1.points }
        }
        let orphan = paragraphs(11, charactersEach: 30)
        let full = paragraphs(20, charactersEach: 30)
        XCTAssertGreaterThan(points(full), points(orphan))
    }

    /// A single-leaf page has no setting to judge, so it is neither rewarded
    /// nor punished for one.
    func testOneLeafEarnsNothingEitherWay() {
        XCTAssertTrue(FolioSetting.signals(for: paragraphs(1, charactersEach: 60)).isEmpty)
    }
}

/// Setting is its own axis on the braid's score.
extension FolioSettingTests {
    /// Folded into `prose`, this signal was swallowed: the prose cap saturates
    /// on any page with decent voice, so the setting points vanished on exactly
    /// the long, rich nights where setting is what differs between candidates.
    func testSettingIsNotSwallowedByTheProseCap() {
        // A page with strong voice signals alone already reaches the prose cap.
        let voiceful = "The kettle's sulking. "
            + String(repeating: "She put the second key on the table and left it. ", count: 12)
        let prose = BraidTastingRoom.Score.cappedProse(
            ProseTaste.signals(in: voiceful).reduce(0) { $0 + $1.points })
        XCTAssertEqual(prose, BraidTastingRoom.Score.maximumProse, "the cap should be saturated")

        // The setting axis still has room to say something.
        let stranded = (0..<11)
            .map { _ in String(repeating: "a", count: 30) }
            .joined(separator: "\n\n")
        XCTAssertLessThan(
            BraidTastingRoom.Score.cappedSetting(
                FolioSetting.signals(for: stranded).reduce(0) { $0 + $1.points }),
            0)
    }
}
