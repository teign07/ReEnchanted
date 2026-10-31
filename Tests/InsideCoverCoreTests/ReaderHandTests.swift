import Foundation
import XCTest

@testable import InsideCoverCore

/// The reader's hand means "you wrote this". It stays true only if nobody else
/// is ever set in it, and if the leaf can tell which of a Page's paragraphs
/// were the reader's.
final class ReaderHandTests: XCTestCase {
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func productionSources() -> [String: String] {
        var out: [String: String] = [:]
        for dir in ["Shared", "InsideCoverApp", "ReEnchantedWidgets", "ReEnchantedShare"] {
            let base = repoRoot().appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(atPath: base.path) else { continue }
            for case let name as String in walker where name.hasSuffix(".swift") {
                out["\(dir)/\(name)"] = (try? String(contentsOf: base.appendingPathComponent(name), encoding: .utf8)) ?? ""
            }
        }
        XCTAssertGreaterThan(out.count, 40, "the lint found almost no source; the path is wrong")
        return out
    }

    // MARK: Lint

    /// A hand named anywhere but `BookHand` is a hand nobody decided: that is
    /// how a Cast note, a caption and a lesson slip all came to be printed in
    /// the reader's handwriting.
    func testHandwritingFacesAreChosenOnlyByBookHand() {
        let offenders = productionSources()
            .filter { path, text in
                path != "InsideCoverApp/BookHands.swift"
                    && (text.contains("BradleyHand") || text.contains("\"Noteworthy"))
            }
            .keys.sorted()
        XCTAssertEqual(offenders, [], "set handwriting through BookHand.reader / BookHand.book")
    }

    func testReaderInkIsDefinedOnce() {
        let offenders = productionSources()
            .filter { path, text in
                path != "InsideCoverApp/BookHands.swift"
                    && text.contains("red: 0.13, green: 0.20, blue: 0.36")
            }
            .keys.sorted()
        XCTAssertEqual(offenders, [], "the reader's ink is BookHand.readerInk")
    }

    // MARK: ReaderWords

    func testEncodedWordsRoundTripThroughMetadata() {
        let texts = ["The fox crossed the allotment at dawn.", "  ", "Second thing,\nwith a break."]
        let encoded = ReaderWords.encoded(texts)
        XCTAssertEqual(ReaderWords.decoded([ReaderWords.metadataKey: encoded ?? ""]),
                       ["The fox crossed the allotment at dawn.", "Second thing,\nwith a break."])
        XCTAssertNil(ReaderWords.encoded(["", " "]))
        XCTAssertEqual(ReaderWords.decoded([:]), [])
    }

    func testAWholeSentenceOrParagraphOfTheReadersIsTheirs() {
        let theirs = ["I walked the long way round because the bridge was shut.\n\nThe river was the colour of tea and loud with it."]
        XCTAssertTrue(ReaderWords.isReaders(
            "I walked the long way round because the bridge was shut.", among: theirs))
        XCTAssertTrue(ReaderWords.isReaders(
            "The river was the colour of tea   and loud with it.", among: theirs),
            "spacing differences from the leaf's paragraph split are not a different author")
        XCTAssertTrue(ReaderWords.isReaders("“Short and mine.”", among: ["Short and mine."]),
                      "a quoted copy of their whole sentence is still theirs")
    }

    func testTheBooksWordsAreNeverClaimedForTheReader() {
        let theirs = ["Yes. I went back for the umbrella and it was gone."]
        XCTAssertFalse(ReaderWords.isReaders("Yes.", among: theirs),
                       "a short line that merely occurs in their writing is not theirs")
        XCTAssertFalse(ReaderWords.isReaders(
            "What did you go back for, really?", among: theirs))
        XCTAssertFalse(ReaderWords.isReaders("Anything", among: []))
    }

    func testAPagewrightPagesScrapListIsNotTheReaders() {
        let page = BookPage(
            id: "pw", type: .plainPage, promptText: "",
            userInput: "My note about the market.\n\nScraps bound here: Photograph: stall",
            tags: ["pagewright"], sourceID: "pagewright", origin: .userAuthored
        )
        let words = ReaderWords.decoded([ReaderWords.metadataKey: ReaderWords.encoded(page.readerAuthoredTexts) ?? ""])
        XCTAssertTrue(ReaderWords.isReaders("My note about the market.", among: words))
        XCTAssertFalse(ReaderWords.isReaders("Scraps bound here: Photograph: stall", among: words))
    }
}
