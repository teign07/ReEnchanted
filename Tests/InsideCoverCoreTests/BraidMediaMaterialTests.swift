import Foundation
import XCTest

@testable import InsideCoverCore

/// A kept photograph, a voice note, and a PageWright leaf are receipts.
///
/// The deterministic writer read `userInput ?? playerReply ?? promptText` and
/// nothing else, so a page whose whole content was a photograph counted as a
/// page with no words in it: it scored last, it dropped out under the
/// lived-beat allowance, and on the way it dragged the night's character count
/// down into the glimpse band. An evening that was one photograph produced a
/// braid that did not know the photograph existed.
final class BraidMediaMaterialTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private func photoPage() -> BookPage {
        var page = BookPage(
            id: "photo", type: .illuminatedPhoto, createdAt: date("2026-09-18T12:00:00Z"),
            promptText: "?", userInput: "", origin: .userAuthored)
        page.mediaAssets = [BookPageMediaAsset(
            id: "a1", kind: .photoLibraryAsset, reference: "ph1",
            caption: "The heron on the roof of the car park.")]
        return page
    }

    private func voicePage() -> BookPage {
        var page = BookPage(
            id: "audio", type: .diary, createdAt: date("2026-09-18T18:00:00Z"),
            promptText: "?", userInput: "", origin: .userAuthored)
        page.mediaAssets = [BookPageMediaAsset(
            id: "a2", kind: .audioFile, reference: "/tmp/a.m4a", caption: "A recording",
            metadata: [BookPageMediaAsset.voiceTranscriptMetadataKey:
                        "I read it out loud to see if it held up."])]
        return page
    }

    private func pagewrightPage() -> BookPage {
        var page = BookPage(
            id: "wright", type: .plainPage, createdAt: date("2026-09-18T19:00:00Z"),
            promptText: "?", userInput: "I glued the brass compass onto the second leaf.",
            origin: .userAuthored)
        page.sourceID = "pagewright"
        return page
    }

    private func day(_ pages: [BookPage]) -> BookDay {
        BookDay(id: "2026-09-18", date: date("2026-09-18T21:00:00Z"), pages: pages)
    }

    private func braid(_ pages: [BookPage]) -> String {
        DeterministicBraidwright.composition(for: day(pages), context: .empty).text
    }

    // MARK: - The evidence itself

    func testAVoiceTranscriptOutranksACaptionAsEvidence() {
        XCTAssertEqual(
            BraidPromptBuilder.mediaEvidence(for: voicePage()),
            "I read it out loud to see if it held up.")
    }

    func testACaptionIsEvidenceWhenThereIsNoTranscript() {
        XCTAssertEqual(
            BraidPromptBuilder.mediaEvidence(for: photoPage()),
            "The heron on the roof of the car park.")
    }

    func testAPageWithNoMediaHasNoMediaEvidence() {
        XCTAssertNil(BraidPromptBuilder.mediaEvidence(for: pagewrightPage()))
    }

    // MARK: - Reaching the page

    func testAKeptPhotographReachesTheBraid() {
        XCTAssertTrue(braid([photoPage()]).contains("heron"), braid([photoPage()]))
    }

    func testAKeptVoiceNoteReachesTheBraid() {
        XCTAssertTrue(braid([voicePage()]).contains("held up"), braid([voicePage()]))
    }

    func testAPageWrightLeafReachesTheBraid() {
        XCTAssertTrue(braid([pagewrightPage()]).contains("compass"), braid([pagewrightPage()]))
    }

    /// A media page used to fall through to `promptText`, which is the Book's
    /// own question, so a bare "?" reached the finished page as prose.
    func testAMediaPageNeverPrintsItsPromptAsProse() {
        let text = braid([photoPage(), voicePage()])
        for line in text.components(separatedBy: .newlines) {
            XCTAssertNotEqual(line.trimmingCharacters(in: .whitespaces), "?", text)
        }
        XCTAssertFalse(text.contains(" ? "), text)
    }

    /// The real contract: a photographed evening counts exactly as much as the
    /// same evening typed out. Not that media makes a night big - three short
    /// pages is honestly a glimpse either way - but that the Book cannot tell
    /// the difference between a line you wrote and a line you said.
    func testKeptMediaCountsThesameAsTypingIt() {
        let spoken = day([photoPage(), voicePage()])
        let typed = day([
            BookPage(
                id: "photo", type: .illuminatedPhoto, createdAt: date("2026-09-18T12:00:00Z"),
                promptText: "?", userInput: "The heron on the roof of the car park.",
                origin: .userAuthored),
            BookPage(
                id: "audio", type: .diary, createdAt: date("2026-09-18T18:00:00Z"),
                promptText: "?", userInput: "I read it out loud to see if it held up.",
                origin: .userAuthored)
        ])
        XCTAssertEqual(
            BraidPromptBuilder.taleReading(for: spoken).scale,
            BraidPromptBuilder.taleReading(for: typed).scale)
    }

    /// Media used to sort last by word count and be the first thing cut. A
    /// photograph kept beside one diary line should still reach the page.
    func testAPhotographIsNotTheFirstThingCut() {
        let diary = BookPage(
            id: "text", type: .diary, createdAt: date("2026-09-18T08:00:00Z"),
            promptText: "?", userInput: "I walked past the old bakery and sat on the wall.",
            origin: .userAuthored)
        let text = braid([diary, photoPage()])
        XCTAssertTrue(text.contains("heron"), text)
        XCTAssertTrue(text.contains("bakery"), text)
    }
}
