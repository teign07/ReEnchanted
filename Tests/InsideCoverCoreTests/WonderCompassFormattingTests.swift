import XCTest
@testable import InsideCoverCore

final class WonderCompassFormattingTests: XCTestCase {
    private func sections() throws -> [ReferenceSnippet] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(
            BookReferenceLibraryPayload.self,
            from: Data(contentsOf: root.appendingPathComponent("Shared/BookReferenceLibrary.json"))
        ).wonderCompass
    }

    /// Direction words are left out: "Notice: …" is shown as the North step
    /// without the manuscript ever saying "north".
    private func words(_ text: String) -> [String: Int] {
        let directions = Set(WonderCompassDirection.allCases.map(\.rawValue))
        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !directions.contains($0) }
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    private func text(of block: WonderCompassBlock) -> String {
        switch block {
        case .part(let label, let title, let subtitle): return [label, title, subtitle ?? ""].joined(separator: " ")
        case .opener(let kicker, let title, _): return [kicker ?? "", title].joined(separator: " ")
        case .lede(let text), .prose(let text), .keyLine(let text), .kicker(let text),
             .credit(let text), .caption(let text):
            return text
        case .heading(let text, _): return text
        case .compass(let direction, let label, let detail, let text):
            return [direction.rawValue, label ?? "", detail ?? "", text ?? ""].joined(separator: " ")
        case .labeled(let label, let text): return label + " " + text
        case .list(let items), .numbered(let items): return items.joined(separator: " ")
        case .summary(let title, let items), .quickWin(let title, let items), .certificate(let title, let items):
            return ([title] + items.map(text(of:))).joined(separator: " ")
        case .souvenir(let title, _): return title
        case .illustration: return ""
        case .contents(let links): return links.map(\.label).joined(separator: " ")
        }
    }

    /// Formatting may restyle the manuscript but never lose, repeat or
    /// reword it: every word of every section comes out exactly once.
    func testEveryWordOfTheManuscriptSurvivesFormatting() throws {
        for section in try sections() {
            let blocks = section.wonderCompassBlocks(for: section.body)
            let formatted = blocks.map(text(of:)).joined(separator: " ")
            XCTAssertEqual(words(formatted), words(section.body), section.id)
        }
    }

    /// The EPUB import once left typesetting ligatures ("oﬀ") in the text;
    /// they show with a gap and break search for the word.
    func testManuscriptHasNoTypesettingLigatures() throws {
        for section in try sections() {
            XCTAssertNil(section.body.unicodeScalars.first { (0xFB00...0xFB06).contains($0.value) }, section.id)
        }
    }

    func testChapterSevenReadsLikeABook() throws {
        let chapter = try XCTUnwrap(try sections().first { $0.id == "wonder-compass-chapter7" })
        let blocks = chapter.wonderCompassBlocks(for: chapter.body)
        XCTAssertEqual(blocks.first, .opener(kicker: "Chapter 7", title: "East = Embark", direction: .east))
        XCTAssertTrue(blocks.contains(.lede("We’ve arrived at the most dangerous moment in the entire process.")))
        XCTAssertTrue(blocks.contains(.list([
            "Tracking alone: 38% success",
            "Motivational pamphlet: 35% success",
            "Pamphlet + specific plan: 91% success",
        ])))
        XCTAssertTrue(blocks.contains(.labeled(label: "The Bribe", text: "Wearing your favorite warm coat.")))
        XCTAssertTrue(blocks.contains(.caption("The 3-D Adventure Recipe")))
        XCTAssertTrue(blocks.contains { if case .summary(let title, _) = $0 { return title == "Chapter 7 Summary" }; return false })
        XCTAssertTrue(blocks.contains { if case .quickWin = $0 { return true }; return false })
        XCTAssertEqual(blocks.last, .souvenir(title: "Your One Sentence Souvenir", lines: 2))
    }

    func testCompassStepsKeepTheirDirection() {
        XCTAssertEqual(
            WonderCompassFormatter.compass("NORTH = NOTICE (The Spark)"),
            .compass(.north, label: "Notice", detail: "The Spark", text: nil)
        )
        XCTAssertEqual(
            WonderCompassFormatter.compass("East (Embark): Walk to the bakery."),
            .compass(.east, label: "Embark", detail: nil, text: "Walk to the bakery.")
        )
        XCTAssertEqual(
            WonderCompassFormatter.compass("West: The bread was still warm."),
            .compass(.west, label: nil, detail: nil, text: "The bread was still warm.")
        )
        XCTAssertNil(WonderCompassFormatter.compass("North is for NOTICE: look up."))
    }

    /// Layout notes name paragraphs by their exact text; a prose edit that
    /// changes one must update the note too.
    func testLayoutNotesNameRealParagraphs() throws {
        for section in try sections() {
            guard let notes = section.layout else { continue }
            let paragraphs = Set(section.body.components(separatedBy: "\n\n").map(WonderCompassFormatter.normalized))
            let named = (notes.majorHeadings ?? []) + (notes.headings ?? [])
                + (notes.notHeadings ?? []) + (notes.keyLines ?? [])
            for text in named {
                XCTAssertTrue(paragraphs.contains(WonderCompassFormatter.normalized(text)), "\(section.id): \(text)")
            }
        }
    }

    // MARK: Writing in the book

    func testSignedSlipAndSouvenirComposeInReadingOrder() throws {
        let chapter = try XCTUnwrap(try sections().first { $0.id == "wonder-compass-chapter4b" })
        let blocks = chapter.wonderCompassBlocks(for: chapter.body)
        let slip = try XCTUnwrap(blocks.firstIndex { if case .certificate = $0 { return true }; return false })
        let souvenir = try XCTUnwrap(blocks.lastIndex { if case .souvenir = $0 { return true }; return false })
        XCTAssertEqual(WonderCompassWriting.compose(blocks: blocks, answers: [:], date: "26 October 2026"), "")

        let answers = [
            WonderCompassWriting.blankKey(block: slip, item: 0, blank: 0): "Rabbit",
            WonderCompassWriting.signatureKey(block: slip): "Rabbit",
            WonderCompassWriting.souvenirKey(block: souvenir): "The kettle sang flat.",
        ]
        let ink = WonderCompassWriting.compose(blocks: blocks, answers: answers, date: "26 October 2026")
        XCTAssertTrue(ink.hasPrefix("THE PERMISSION SLIP\nI, Rabbit, hereby grant myself permission to be inefficient."))
        XCTAssertTrue(ink.contains("Signed, Rabbit\nDate: 26 October 2026"))
        XCTAssertTrue(ink.hasSuffix("Your One Sentence Souvenir: The kettle sang flat."))
        // Unanswered blanks stay visibly blank rather than vanishing.
        XCTAssertTrue(ink.contains("The thing my Caveman says most often is: _________"))
    }

    func testFailureSlipBlankIsARunOfSpaces() {
        XCTAssertEqual(WonderCompassWriting.blankCount("I,                           , give myself permission to fail at this."), 1)
        XCTAssertEqual(WonderCompassWriting.filled("I,                           , give myself", answers: ["Rabbit"]), "I, Rabbit, give myself")
    }

    func testWritingKeepsAsItsOwnSmallPage() throws {
        let chapter = try XCTUnwrap(try sections().first { $0.id == "wonder-compass-chapter7" })
        let page = WonderCompassPageSourceAdapter().writingSurface(for: chapter)
        XCTAssertEqual(page.payload.headline, "Written in Chapter 7")
        XCTAssertNil(page.payload.metadata["readingPage"])
        XCTAssertEqual(page.payload.metadata["wonderCompassWriting"], "true")
        XCTAssertFalse(page.payload.body.contains("couch"), "the chapter itself is not copied into the keep")
    }

    // MARK: Dares and the book

    func testEveryDareNamesARealChapterOfTheBook() throws {
        let chapterIDs = Set(try sections().map(\.id))
        let placeStems = ["local-bookstore-question", "local-library-poem", "local-wild-voice", "local-water-verdict",
                          "local-secret-favorite", "creative-drop", "local-curiosity"]
        for id in WickerDareRegistry.immediate.map(\.id) + placeStems.map({ $0 + "-some-place" }) {
            let practice = try XCTUnwrap(WickerDareCompass.practice(forDareID: id), id)
            XCTAssertTrue(chapterIDs.contains(practice.chapterID), "\(id) → \(practice.chapterID)")
        }
        XCTAssertEqual(WickerDareCompass.practice(forDareID: "route-mutiny")?.direction, .east)
        XCTAssertEqual(WickerDareCompass.practice(forDareID: "tell-the-plant")?.chapterID, "wonder-compass-chapter8b")
    }

    func testMarkAThresholdAsksForTheDelight() throws {
        let plan = try XCTUnwrap(AcademyActivityRegistry.activities["wayfinding-kineticism"])
        XCTAssertEqual(plan.fields.map(\.id), ["threshold", "destination", "delight", "return"])
    }
}
