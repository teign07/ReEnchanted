import XCTest
@testable import InsideCoverCore

/// A reflective Page's entire claim is that it read the reader. These assert the
/// line between what the reader wrote and what the Book wrote, at the exact
/// point where a reflective surface decides what it may say back.
///
/// The bug these exist for: the Welcome's own prose ("You picked up this Page
/// on…") lives in `userInput` on a generated Page, so every surface that
/// measured "did the reader write something?" by asking whether `userInput` was
/// non-empty treated the Book's writing as the reader's, and Notices and
/// Remembers quoted it back as evidence about them.
final class ReflectiveMaterialProvenanceTests: XCTestCase {
    private func page(
        origin: BookPageOrigin,
        userInput: String = "",
        playerReply: String = "",
        tags: [String] = []
    ) -> BookPage {
        BookPage(
            type: .souvenir,
            promptText: "A prompt the Book wrote.",
            userInput: userInput,
            playerReply: playerReply,
            tags: tags,
            origin: origin
        )
    }

    func testBookAuthoredPageSuppliesNoReflectiveMaterial() {
        let welcome = page(
            origin: .generated,
            userInput: "You picked up this Page on Tuesday at 4:12, while the rain kept its own counsel."
        )
        XCTAssertNil(
            welcome.reflectiveMaterial,
            "Generated prose must never be offered as something the reader said."
        )
        XCTAssertFalse(
            welcome.canSupplyReflectiveMaterial,
            "A Page the reader put nothing into cannot be material for a Page that reflects."
        )
    }

    func testReaderWritingIsReflectiveMaterial() {
        let kept = page(origin: .userAuthored, userInput: "The kettle sulked all morning and I let it.")
        XCTAssertEqual(kept.reflectiveMaterial, "The kettle sulked all morning and I let it.")
        XCTAssertTrue(kept.canSupplyReflectiveMaterial)
    }

    /// A reply is the tell that `userInput` holds the Book's prose: the reader
    /// answered something already written. Only their answer may be quoted.
    func testReplyToBookProseQuotesOnlyTheReply() {
        let letter = page(
            origin: .userAuthored,
            userInput: "The Book wrote a long letter here, in its own voice.",
            playerReply: "I read it twice."
        )
        XCTAssertEqual(letter.reflectiveMaterial, "I read it twice.")
    }

    /// Being material and being quotable are different questions. Collapsing
    /// them made Pages carrying only a photograph unrememberable.
    func testPhotographIsMaterialWithoutBeingQuotable() {
        var photoPage = page(origin: .userAuthored)
        photoPage.mediaAssets = [
            BookPageMediaAsset(
                id: "asset-1",
                kind: .photoLibraryAsset,
                reference: "local-identifier",
                caption: "",
                sourceID: "reader-camera"
            )
        ]
        XCTAssertTrue(
            photoPage.hasReaderPhotograph,
            "Precondition: the Page carries a reader photograph."
        )
        XCTAssertTrue(
            photoPage.canSupplyReflectiveMaterial,
            "A photograph the reader took is unmistakably theirs."
        )
        XCTAssertNil(
            photoPage.reflectiveMaterial,
            "A photograph supplies nothing to put in quotation marks."
        )
    }

    // MARK: - The relationships between the accessors

    /// These hold by construction today. Pinning them means a later change to
    /// any one accessor cannot quietly put the family out of step — which is
    /// the shape of every leak this boundary has had so far.
    func testTheAccessorsStayInStepAcrossEveryShapeOfPage() {
        for page in Self.everyShape {
            if let words = page.readerAuthoredTextForAnalysis {
                XCTAssertEqual(
                    page.reflectiveMaterial, words,
                    "\(page.id): the reader's own writing always outranks a rendered choice"
                )
            }
            if page.reflectiveMaterial != nil {
                XCTAssertTrue(
                    page.canSupplyReflectiveMaterial,
                    "\(page.id): something quotable must also be usable"
                )
            }
            XCTAssertEqual(
                page.canSupplyReflectiveMaterial, page.hasReaderContribution,
                "\(page.id): the reflective policy and the fact have drifted apart"
            )
            if !page.hasReaderContribution {
                XCTAssertNil(
                    page.reflectiveMaterial,
                    "\(page.id): a Page the reader put nothing into may never be quoted"
                )
            }
        }
    }

    func testARenderedChoiceIsNeverMeasuredAsTheReadersDiction() {
        // `reflectiveMaterial` may say "You chose the blue door." — that is the
        // Book's phrasing of a decision. Anything measuring how the reader
        // writes must not count those words as theirs.
        let choiceOnly = BookPage(
            type: .narrativeOS,
            promptText: "A scene",
            userInput: "The Book wrote the scene.\n\nChosen path: Something Surprising",
            origin: .generated
        )
        XCTAssertNil(choiceOnly.readerAuthoredTextForAnalysis)
        XCTAssertEqual(choiceOnly.reflectiveMaterial, "You chose Something Surprising.")
        XCTAssertTrue(choiceOnly.canSupplyReflectiveMaterial)
    }

    /// One of each shape the boundary has to hold for.
    private static let everyShape: [BookPage] = [
        BookPage(id: "book-only", type: .gossip, promptText: "Academy business",
                 userInput: "The staircase held a secret meeting.", origin: .generated),
        BookPage(id: "reader-only", type: .diary, promptText: "What did the day hand you?",
                 userInput: "The coat stayed dark at the shoulders all morning.", origin: .userAuthored),
        BookPage(id: "reply-to-book", type: .letter, promptText: "A letter",
                 userInput: "Generated letter prose.",
                 playerReply: "I have been waiting for permission to begin."),
        BookPage(id: "margin-note", type: .narrativeOS, promptText: "A scene",
                 userInput: "The Book wrote the scene.\n\nMargin note: I picked the odd door.",
                 origin: .generated),
        BookPage(id: "choice-only", type: .narrativeOS, promptText: "A scene",
                 userInput: "The Book wrote it.\n\nChosen path: Something Surprising",
                 origin: .generated),
        BookPage(id: "welcome", type: .welcome, promptText: "You picked up this Page",
                 userInput: "", origin: .generated),
        BookPage(id: "empty", type: .diary, promptText: "", userInput: "", origin: .userAuthored)
    ]
}
