import XCTest
@testable import InsideCoverCore

final class WonderCompassContentsTests: XCTestCase {
    private func library() throws -> BookReferenceLibraryPayload {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(
            BookReferenceLibraryPayload.self,
            from: Data(contentsOf: root.appendingPathComponent("Shared/BookReferenceLibrary.json"))
        )
    }

    func testEveryContentsListingKeepsItsLabelAndHasAnExistingReadingPage() throws {
        let sections = try library().wonderCompass
        let first = try XCTUnwrap(sections.first { $0.id == "wonder-compass-read-this-first" })
        let paragraphs = first.body.components(separatedBy: "\n\n")
        let heading = try XCTUnwrap(paragraphs.firstIndex(of: "Table Of Contents"))
        let labels = paragraphs[heading + 1].components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let links = try XCTUnwrap(first.contentsLinks)
        XCTAssertEqual(links.map(\.label), labels)
        XCTAssertEqual(links.count, 55)
        XCTAssertEqual(Set(links.map(\.id)).count, links.count)
        for link in links {
            let destination = try XCTUnwrap(sections.first { $0.id == link.sectionID }, link.label)
            let page = WonderCompassPageSourceAdapter().readingSurface(for: destination)
            XCTAssertEqual(page.payload.metadata["snippetID"], link.sectionID)
            XCTAssertEqual(page.payload.metadata["readingPage"], "true")
            XCTAssertEqual(page.payload.body, destination.body)
            if link.label.hasPrefix("Chapter ") {
                let number = link.label.components(separatedBy: ":")[0].dropFirst("Chapter ".count)
                XCTAssertEqual(link.sectionID, "wonder-compass-chapter\(number.lowercased())")
            }
            if link.label.hasPrefix("Appendix ") {
                let letter = link.label.components(separatedBy: ":")[0].dropFirst("Appendix ".count)
                XCTAssertEqual(link.sectionID, "wonder-compass-appendix-\(letter.lowercased())")
            }
        }
    }

    func testContentsBecomeOneNavigationBlockWhileCoverAndPlatesKeepTheirOrder() throws {
        let first = try XCTUnwrap(try library().wonderCompass.first)
        let blocks = first.readingBlocks(for: first.body)
        guard case .illustration(let cover)? = blocks.first else {
            return XCTFail("The cover should still lead the reading page")
        }
        XCTAssertEqual(cover.id, "wc-cover")
        let contents = blocks.compactMap { block -> [ReferenceContentsLink]? in
            if case .contents(let links) = block { return links }
            return nil
        }
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents.first, first.contentsLinks)
        let plates = blocks.compactMap { block -> String? in
            if case .illustration(let plate) = block { return plate.id }
            return nil
        }
        XCTAssertEqual(plates, first.illustrations?.map(\.id))
        let prose = blocks.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }
        XCTAssertTrue(prose.contains { $0.hasSuffix("Table Of Contents") })
        XCTAssertTrue(prose.contains { $0.hasPrefix("won·der") })
    }

    func testChapterMentionsAndIncompleteContentsRemainOrdinaryText() {
        let snippet = ReferenceSnippet(
            id: "reference", sourceID: "wonder-compass", title: "Reference", prompt: "Read",
            body: "", tags: [], contentsLinks: [
                ReferenceContentsLink(label: "Chapter 1A", sectionID: "wonder-compass-chapter1a"),
                ReferenceContentsLink(label: "Chapter 1B", sectionID: "wonder-compass-chapter1b")
            ]
        )
        for prose in ["Try Chapter 1A later.", "Chapter 1A", "A chapter without a contents list."] {
            XCTAssertEqual(snippet.readingBlocks(for: prose), [.text(prose)])
        }
    }

    func testEveryReadingPageHasContentAndUsesBoundedLosslessTextRuns() throws {
        let sections = try library().wonderCompass
        XCTAssertEqual(sections.count, 48)
        for section in sections {
            let page = WonderCompassPageSourceAdapter().readingSurface(for: section)
            let blocks = section.readingBlocks(for: page.payload.body)
            XCTAssertFalse(blocks.isEmpty, section.id)
            for block in blocks {
                guard case .text(let text) = block else { continue }
                let chunks = ReferenceSnippet.readingTextChunks(for: text)
                XCTAssertEqual(chunks.joined(), text, section.id)
                XCTAssertTrue(chunks.allSatisfy { !$0.isEmpty && $0.count <= ReferenceSnippet.readingTextChunkLimit }, section.id)
            }
            // The shortest appendices are authored worksheets/menus. Their
            // plates, rather than a title alone, are the reading content.
            if section.body.count < 100 {
                XCTAssertTrue(blocks.contains { if case .illustration = $0 { return true }; return false }, section.id)
            }
        }
        let notes = try XCTUnwrap(sections.first { $0.id == "wonder-compass-notes-references" })
        XCTAssertTrue(notes.body.contains("Killingsworth & Gilbert (2010)"))
        XCTAssertTrue(notes.body.contains("Rotter, J. B. (1966)"))
        XCTAssertGreaterThan(ReferenceSnippet.readingTextChunks(for: notes.body).count, 100)
    }

    func testReadingTextChunksPreserveWhitespaceUnicodeAndLongParagraphs() {
        for text in [
            "",
            "A short reference.\n\nAnother paragraph.\n",
            String(repeating: "A long paragraph 👩🏽‍🔬 with references. ", count: 200),
            String(repeating: "🧭", count: 4_001),
            String(repeating: " ", count: 2_010) + "The final citation."
        ] {
            let chunks = ReferenceSnippet.readingTextChunks(for: text)
            XCTAssertEqual(chunks.joined(), text)
            XCTAssertTrue(chunks.allSatisfy { !$0.isEmpty && $0.count <= ReferenceSnippet.readingTextChunkLimit })
        }
    }

    func testOlderReferenceEntriesStillDecodeAndReadWithoutContentsMetadata() throws {
        let data = Data(#"{"id":"old","sourceID":"wonder-compass","title":"Old","prompt":"Read","body":"An older page.","tags":[]}"#.utf8)
        let snippet = try JSONDecoder().decode(ReferenceSnippet.self, from: data)
        XCTAssertNil(snippet.contentsLinks)
        XCTAssertEqual(snippet.readingBlocks(for: snippet.body), [.text(snippet.body)])
    }
}
