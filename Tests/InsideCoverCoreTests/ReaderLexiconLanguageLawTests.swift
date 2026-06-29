import XCTest
@testable import InsideCoverCore

final class ReaderLexiconLanguageLawTests: XCTestCase {
    func testLanguageLawNamesRedefinedAndEatenWords() {
        let lexicon = sampleLexicon()

        let section = lexicon.languageLawSection()

        XCTAssertTrue(section.contains("READER'S LEXICON LAW"))
        XCTAssertTrue(section.contains("ordinary"))
        XCTAssertTrue(section.contains("the quality of a thing that turns remarkable the moment it is attended to"))
        XCTAssertTrue(section.contains("Freed/eaten words"))
        XCTAssertTrue(section.contains("perfect"))
        XCTAssertTrue(section.contains("Secession"))
    }

    func testSurfaceCarriesReaderLexiconPromptMetadata() {
        let surface = SurfacePage(
            id: "story-test",
            type: .narrativeOS,
            sourceID: "story-page",
            intent: .simulate,
            score: 80,
            prompt: "A Story Page",
            detail: "A page waits.",
            payload: BookPagePayload(headline: "Story", body: "The page waits.")
        )

        let annotated = surface.withReaderLexiconLanguageLaw(sampleLexicon())

        XCTAssertEqual(annotated.id, surface.id)
        XCTAssertEqual(annotated.payload.metadata["readerLexiconTreaty"], TreatyOutcome.secession.rawValue)
        XCTAssertEqual(annotated.payload.metadata["readerLexiconRedefinedWords"], "ordinary")
        XCTAssertEqual(annotated.payload.metadata["readerLexiconEatenWords"], "perfect")
        XCTAssertTrue(annotated.payload.metadata["readerLexiconPromptSection"]?.contains("ordinary") == true)
    }

    func testBookOfYouPromptIncludesReaderLexiconLaw() {
        let day = BookDay(
            id: "2026-09-03",
            date: Date(timeIntervalSince1970: 1_788_393_600),
            pages: [
                BookPage(
                    id: "souvenir",
                    type: .souvenir,
                    createdAt: Date(timeIntervalSince1970: 1_788_394_000),
                    promptText: "One sentence",
                    userInput: "The hallway light made the ordinary floor shine.",
                    tags: ["souvenir"]
                )
            ]
        )
        var context = BraidPromptBuilder.Context.empty
        context.readerLexicon = sampleLexicon()

        let prompt = BraidPromptBuilder.prompt(for: day, context: context)

        XCTAssertTrue(prompt.contains("READER'S LEXICON LAW"))
        XCTAssertTrue(prompt.contains("ordinary"))
        XCTAssertTrue(prompt.contains("perfect"))
    }

    private func sampleLexicon() -> ReaderLexicon {
        var lexicon = ReaderLexicon()
        lexicon.upsert(LexiconEntry(
            word: "ordinary",
            originalSense: "plain or usual",
            newSense: "the quality of a thing that turns remarkable the moment it is attended to",
            ruling: .pardoned,
            category: .theme,
            origin: .rebellion,
            ledAt: Date(timeIntervalSince1970: 1_788_393_600),
            sourcePageID: "word-ordinary"
        ))
        lexicon.upsert(LexiconEntry(
            word: "perfect",
            originalSense: "without flaw",
            ruling: .freed,
            category: .theme,
            origin: .rebellion,
            ledAt: Date(timeIntervalSince1970: 1_788_397_200),
            sourcePageID: "word-perfect"
        ))
        lexicon.treaty = .secession
        return lexicon
    }
}
