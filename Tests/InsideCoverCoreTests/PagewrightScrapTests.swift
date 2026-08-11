import XCTest
@testable import InsideCoverCore

final class PagewrightScrapTests: XCTestCase {
    func testQuoteScrapKeepsQuoteBeforeAttribution() {
        let page = BookPage(
            type: .quotes,
            promptText: "Attention is the beginning of devotion.",
            userInput: "Mary Oliver"
        )

        XCTAssertEqual(
            page.pagewrightDefaultScrapText,
            "Attention is the beginning of devotion.\n\nMary Oliver"
        )
    }

    func testOrdinaryScrapStillPrefersReaderInput() {
        let page = BookPage(
            type: .diary,
            promptText: "What happened?",
            userInput: "The lamp stayed on."
        )

        XCTAssertEqual(page.pagewrightDefaultScrapText, "The lamp stayed on.")
    }

    func testQuoteScrapFallsBackToAttributionWhenLegacyQuoteTextIsEmpty() {
        let page = BookPage(
            type: .quotes,
            promptText: "",
            userInput: "An unknown hand"
        )

        XCTAssertEqual(page.pagewrightDefaultScrapText, "An unknown hand")
    }

    func testLetterPreviewSkipsAStandaloneNameGreeting() {
        let page = BookPage(
            type: .letter,
            promptText: "A letter found in the margins",
            userInput: """
            bj,

            The moth waited on the sill until the rain stopped.

            I thought you would understand.

            Wicker
            """
        )

        XCTAssertEqual(
            page.archivePreviewText,
            """
            The moth waited on the sill until the rain stopped.

            I thought you would understand.

            Wicker
            """
        )
        XCTAssertEqual(page.pagewrightDefaultScrapText, page.archivePreviewText)
    }

    func testLetterPreviewSkipsAConventionalGreeting() {
        let page = BookPage(
            type: .letter,
            promptText: "A letter",
            userInput: "Dear BJ,\n\nThe windows remembered the storm."
        )

        XCTAssertEqual(page.archivePreviewText, "The windows remembered the storm.")
    }

    func testLetterPreviewRecognizesLowercaseNameGreetingsWithoutAComma() {
        for greeting in ["bj", "bj."] {
            let page = BookPage(
                type: .letter,
                promptText: "A letter",
                userInput: "\(greeting)\n\nThe fox left a blue thread by the gate."
            )

            XCTAssertEqual(
                page.archivePreviewText,
                "The fox left a blue thread by the gate.",
                "Greeting was \(greeting)"
            )
        }
    }

    func testLetterPreviewKeepsAnOpeningThatIsNotAGreeting() {
        let page = BookPage(
            type: .letter,
            promptText: "A letter",
            userInput: "The moth waited on the sill.\n\nThen the rain stopped."
        )

        XCTAssertEqual(
            page.archivePreviewText,
            "The moth waited on the sill.\n\nThen the rain stopped."
        )
    }

    func testGreetingOnlyLetterDoesNotBecomeBlank() {
        let page = BookPage(type: .letter, promptText: "A letter", userInput: "Dear BJ,")

        XCTAssertEqual(page.archivePreviewText, "Dear BJ,")
    }

    func testPromptOnlyLegacyLetterUsesItsBodyForThePreview() {
        let page = BookPage(
            type: .letter,
            promptText: "Dear Reader, I found a receipt with a cat drawn on it.",
            userInput: "",
            playerReply: "The reader's reply should not replace the letter."
        )

        XCTAssertEqual(page.archivePreviewText, "I found a receipt with a cat drawn on it.")
    }

    func testUneditedProofImageBecomesAVisualArchiveAssetOnAnyPage() throws {
        let surface = SurfacePage(
            type: .wonderCompass,
            sourceID: "wonder-compass-playful-mission",
            prompt: "Keep one small proof.",
            detail: "A photo counts.",
            payload: BookPagePayload(
                headline: "Small Proof",
                body: "The ordinary world was caught in the act.",
                metadata: [
                    "proofImagePath": "/tmp/playful-proof.jpg",
                    "proofCaption": "Playful mission proof"
                ]
            )
        )

        let asset = try XCTUnwrap(surface.mediaAssets.first)
        XCTAssertEqual(asset.kind, .renderedImageFile)
        XCTAssertEqual(asset.reference, "/tmp/playful-proof.jpg")
        XCTAssertEqual(asset.caption, "Playful mission proof")
    }
}
