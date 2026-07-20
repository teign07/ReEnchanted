import XCTest
@testable import InsideCoverCore

final class PagewrightInvitationTests: XCTestCase {
    func testSeedPagesPutVisualAndIlluminatedKeepsOnCanvasFirst() {
        let text = BookPage(
            id: "text",
            type: .diary,
            createdAt: Date(timeIntervalSince1970: 300),
            promptText: "A sentence",
            userInput: "The lamp stayed on."
        )
        let photo = BookPage(
            id: "photo",
            type: .souvenir,
            createdAt: Date(timeIntervalSince1970: 100),
            promptText: "A photograph",
            mediaAssets: [
                BookPageMediaAsset(kind: .photoLibraryAsset, reference: "photo-local-id")
            ]
        )
        let illuminated = BookPage(
            id: "illuminated",
            type: .illuminatedPhoto,
            createdAt: Date(timeIntervalSince1970: 200),
            promptText: "An illuminated plate",
            mediaAssets: [
                BookPageMediaAsset(kind: .renderedImageFile, reference: "/tmp/illuminated.png")
            ]
        )
        let day = BookDay(id: "day", date: Date(), pages: [text, photo, illuminated])

        let result = PlainPageSourceAdapter.pagewrightSeedPages(from: [day])

        XCTAssertEqual(result.map(\.id), ["illuminated", "photo", "text"])
    }

    func testSeedPagesExcludeWelcomeAndHelpPages() {
        let welcome = BookPage(id: "welcome", type: .welcome, promptText: "Welcome")
        let help = BookPage(id: "help", type: .helpTips, promptText: "Help")
        let kept = BookPage(id: "kept", type: .diary, promptText: "Kept", userInput: "A real scrap")
        let day = BookDay(id: "day", date: Date(), pages: [welcome, help, kept])

        XCTAssertEqual(
            PlainPageSourceAdapter.pagewrightSeedPages(from: [day]).map(\.id),
            ["kept"]
        )
    }
}
